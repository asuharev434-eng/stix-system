import SwiftUI
import SystemCore

private enum HistorySelection: Equatable { case memory, temperature(String) }

struct DashboardView: View {
    @ObservedObject var model: MonitorModel
    @ObservedObject var preferences: AppPreferences
    init(model: MonitorModel) { self.model = model; self.preferences = model.preferences }
    @State private var historySelection: HistorySelection?
    private let accent = Color(red: 0.28, green: 0.47, blue: 0.96)
    private func swapRate(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0 / 1_048_576) } ?? "—"
    }
    private func gigabytes(_ value: UInt64?) -> String {
        value.map { String(format: "%.2f ГБ", Double($0) / 1_073_741_824) } ?? "—"
    }
    private func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory) }
    private func rate(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(min(value, Double(Int64.max / 2))), countStyle: .file) + "/с"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.path").font(.system(size: 18, weight: .semibold)).foregroundStyle(accent)
                Text("STIX System").font(.system(size: 16, weight: .semibold))
                Spacer()
                Circle().fill(model.thermalColor).frame(width: 6, height: 6)
                Text(model.thermalTitle).font(.system(size: 10)).foregroundStyle(.secondary)
                Menu {
                    Menu("В строке меню") {
                        ForEach(MenuMetric.allCases, id: \.self) { metric in
                            Button { preferences.menuMetric = metric } label: {
                                if preferences.menuMetric == metric { Label(metric.title, systemImage: "checkmark") }
                                else { Text(metric.title) }
                            }
                        }
                    }
                    Toggle("Запускать при входе", isOn: Binding(get: { preferences.launchAtLogin }, set: preferences.setLogin))
                    Toggle("Уведомлять о проблемах", isOn: Binding(get: { preferences.alertsEnabled }, set: preferences.setAlerts))
                    Button("Проверить уведомления") {
                        Task { do { try await preferences.notifications.test() } catch { preferences.notice = error.localizedDescription } }
                    }
                } label: { Image(systemName: "gearshape").font(.system(size: 11)) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Настройки")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    utilization("CPU", icon: "cpu", value: model.snapshot?.cpu, history: model.cpuHistory, color: accent)
                    Divider().frame(height: 64)
                    utilization("GPU", icon: "square.stack.3d.up", value: model.snapshot?.gpu, history: model.gpuHistory, color: .teal)
                        .help("Загрузка GPU по счётчику драйвера. При нескольких GPU — наиболее загруженный. Если счётчик недоступен — прочерк.")
                }
                Divider()
                HStack {
                    Button { toggleHistory(.memory) } label: {
                        HStack(spacing: 4) {
                            label("Память", icon: "memorychip")
                            Image(systemName: historySelection == .memory ? "chevron.down" : "chevron.right")
                                .font(.system(size: 7)).foregroundStyle(.tertiary)
                        }
                    }.buttonStyle(.plain).help("История RAM за последние 15 минут")
                    Spacer()
                    if let memory = model.snapshot?.memory {
                        Text("\(bytes(memory.used)) / \(bytes(memory.total))").monospacedDigit()
                    } else { Text("—") }
                }.font(.system(size: 12))
                if let memory = model.snapshot?.memory {
                    GeometryReader { geometry in
                        Capsule().fill(.quaternary)
                        Capsule().fill(memory.pressure >= 4 ? Color.red : memory.pressure >= 2 ? Color.orange : accent)
                            .frame(width: geometry.size.width * memory.fraction)
                    }.frame(height: 4)
                    HStack {
                        Text("Доступно \(gigabytes(memory.available))")
                        Spacer()
                        Text("Кэш \(gigabytes(memory.cached))")
                    }.font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
                        .help("Доступно — оценка RAM с учётом освобождаемого файлового кэша и purgeable-памяти. Компрессор остаётся занятой RAM; кэш уже включён в доступную память.")
                    HStack {
                        Text("Давление памяти")
                        Spacer()
                        Circle().fill(memory.pressure >= 4 ? Color.red : memory.pressure == 2 ? Color.orange : memory.pressure == 1 ? Color.green : Color.gray).frame(width: 5, height: 5)
                        Text(memory.pressure == 1 ? "Нормальное" : memory.pressure == 2 ? "Повышенное" : memory.pressure >= 4 ? "Высокое" : "Недоступно")
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    HStack {
                        HStack(spacing: 4) {
                            Text("Swap")
                            Text(gigabytes(memory.swapUsed)).monospacedDigit()
                        }.help("Использованный swap на диске")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Сжато")
                            Text(gigabytes(memory.compressedUsed)).monospacedDigit()
                        }.help("Объём RAM, занимаемый сжатой памятью")
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    HStack {
                        Text("Подкачка")
                        Spacer()
                        Text("↓ \(swapRate(memory.swapReadBytesPerSecond))  ↑ \(swapRate(memory.swapWriteBytesPerSecond)) МБ/с")
                            .monospacedDigit()
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                        .help("Чтение ↓ и запись ↑ страниц swap за последний интервал. Логический объём страниц, не физическая скорость SSD. Значение не измеряет задержки приложений.")
                    if historySelection == .memory {
                        history(model.history.memory.points, title: "RAM", range: "0–\(gigabytes(memory.total))", ceiling: 1)
                    }
                }
                Divider()
                HStack {
                    label("Диск", icon: "internaldrive")
                    Spacer()
                    if let disk = model.snapshot?.disk { Text("\(bytes(disk.free)) свободно").monospacedDigit() }
                    else { Text("—") }
                }.font(.system(size: 12))
                HStack {
                    Text("Чтение  \(rate(model.snapshot?.disk?.readBytesPerSecond))")
                    Spacer()
                    Text("Запись  \(rate(model.snapshot?.disk?.writeBytesPerSecond))")
                }.font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
                    .help("Скорость чтения и записи всех физических дисков Mac")
                HStack {
                    label("Сеть", icon: "network")
                    Spacer()
                    Text("↓ \(rate(model.snapshot?.network?.download))  ↑ \(rate(model.snapshot?.network?.upload))")
                        .monospacedDigit().foregroundStyle(.secondary)
                }.font(.system(size: 10))
                    .help("Входящий ↓ и исходящий ↑ трафик Wi-Fi/Ethernet")
                if let battery = model.snapshot?.battery {
                    HStack {
                        label("Батарея", icon: battery.state == .charging ? "battery.100.bolt" : "battery.100")
                        Spacer()
                        Text("\(Int((battery.fraction * 100).rounded()))% · \(batteryState(battery.state))")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }.font(.system(size: 10))
                }
            }
            .padding(14)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            temperatures
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ПРОЦЕССЫ · ТОП 5").font(.system(size: 9, weight: .semibold)).tracking(1.1)
                    Spacer()
                    Button("CPU") { preferences.processSort = .cpu }
                        .foregroundStyle(preferences.processSort == .cpu ? accent : .secondary).frame(width: 44, alignment: .trailing)
                        .help("Сортировать по CPU; 100% — одно ядро")
                    Button("RAM") { preferences.processSort = .memory }
                        .foregroundStyle(preferences.processSort == .memory ? accent : .secondary).frame(width: 66, alignment: .trailing)
                }.foregroundStyle(.secondary).buttonStyle(.plain).font(.system(size: 9))
                if let processes = model.snapshot?.processes, !processes.isEmpty {
                    ForEach(ProcessUsage.top(processes, by: preferences.processSort)) { process in
                        HStack(spacing: 8) {
                            Text(process.name).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(process.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "—")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                            Text(bytes(process.residentBytes)).monospacedDigit().foregroundStyle(.secondary).frame(width: 66, alignment: .trailing)
                        }.font(.system(size: 11))
                            .help("\(process.name) · PID \(process.id) · резидентная память")
                    }
                } else { Text("Читаю список процессов…").font(.system(size: 11)).foregroundStyle(.secondary) }
            }.padding(.horizontal, 3)
            Divider()
            fans
            if let error = model.message ?? preferences.notice ?? model.hardware?.error ?? model.snapshot?.issues.first {
                Text(error).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Завершить") { model.quit() }.buttonStyle(.plain).help("Вернуть вентиляторы в Авто и завершить приложение")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 382)
        .tint(accent)
    }
    private func toggleHistory(_ id: HistorySelection) {
        historySelection = historySelection == id ? nil : id
    }
    private func batteryState(_ state: BatteryUsage.State) -> String {
        switch state { case .charging: return "Заряжается"; case .external: return "От сети"; case .battery: return "От батареи" }
    }
    private func history(_ points: [HistoryPoint], title: String, range: String, ceiling: Double) -> some View {
        let end = Date().timeIntervalSince1970
        let span = min(900, max(30, end - (points.first?.time ?? end)))
        let spanLabel = span < 60 ? "\(Int(span)) с" : "\(Int(span / 60)) мин"
        return VStack(spacing: 5) {
            HStack { Text("\(title) · \(spanLabel)"); Spacer(); Text(range) }
                .font(.system(size: 9)).foregroundStyle(.secondary)
            if points.contains(where: { $0.value != nil }) {
                HistoryGraph(points: points, start: end - span, end: end, ceiling: ceiling, color: accent).frame(height: 50)
                    .accessibilityLabel("История \(title) за последние 15 минут")
            } else {
                Text("Нет показаний").font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 50)
            }
            HStack { Text("−\(spanLabel)"); Spacer(); Text("Сейчас") }
                .font(.system(size: 8)).foregroundStyle(.tertiary)
        }.help("До 15 минут истории с запуска приложения, только в памяти. Масштаб расширяется по мере накопления данных. Пропуски показаний не соединяются линией.")
    }
    private func utilization(_ title: String, icon: String, value: Double?, history: [Double], color: Color) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                label(title, icon: icon)
                Spacer(minLength: 2)
                Text(value.map { "\(Int(($0 * 100).rounded()))" } ?? "—")
                    .font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 11)).foregroundStyle(.secondary)
            }.font(.system(size: 11))
            Sparkline(values: history, color: color).frame(height: 29)
                .accessibilityLabel("График загрузки \(title) за последнюю минуту")
        }.frame(maxWidth: .infinity)
    }
    private func label(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).foregroundStyle(.secondary).font(.system(size: 12))
    }
    @ViewBuilder private var temperatures: some View {
        if let readings = model.hardware?.temperatures, !readings.isEmpty {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(readings) { reading in
                        Button { toggleHistory(.temperature(reading.id)) } label: {
                            VStack(spacing: 4) {
                                Text(reading.title).font(.system(size: 9))
                                    .foregroundStyle(historySelection == .temperature(reading.id) ? accent : .secondary)
                                Text(reading.celsius.map { "\(Int($0.rounded()))°" } ?? "—")
                                    .font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit()
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .help("\(reading.detail). Нажми для истории за 15 минут.")
                    }
                }
                if case let .temperature(id)? = historySelection, let reading = readings.first(where: { $0.id == id }) {
                    history(model.history.temperatures[id]?.points ?? [], title: reading.title, range: "0–130 °C", ceiling: 130)
                }
            }.padding(.vertical, 3)
        }
    }
    @ViewBuilder private var fans: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                label("Вентиляторы", icon: "fanblades")
                Spacer()
                if model.busy { ProgressView().controlSize(.mini) }
                Picker("Единицы", selection: Binding(get: { preferences.rpmUnits }, set: model.setRPMUnits)) {
                    Text("%").tag(false)
                    Text("об/мин").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 95).controlSize(.mini)
                Toggle("Sync", isOn: Binding(get: { model.syncFans }, set: { model.setSync($0) }))
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 11)).fixedSize()
                    .disabled(model.busy)
            }
            if let fans = model.hardware?.fans, !fans.isEmpty {
                if model.syncFans {
                    HStack(spacing: 15) {
                        ForEach(fans) { fan in rpm(fan, named: false) }
                    }
                    if model.serviceReady { fanControls(id: nil) }
                } else {
                    ForEach(fans) { fan in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { rpm(fan, named: true); Spacer()
                                Text(fan.manual == true ? (fan.target == 0 ? (fan.current < 100 ? "Остановлен" : "Останавливается…") : "Вручную") : "Авто").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            if model.serviceReady { fanControls(id: fan.id) }
                        }
                    }
                }
                if !model.serviceReady {
                    Button(model.needsApproval ? "Разрешить в настройках macOS…" : "Включить управление…") { model.enableService() }
                        .buttonStyle(.bordered).controlSize(.small)
                } else {
                    Text(model.manualBlockReason ?? "CPU/GPU ≥95 °C или потеря связи — обратно в Авто")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            } else {
                Text(model.hardware?.error ?? "Нет доступных вентиляторов").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
    private func rpm(_ fan: FanReading, named: Bool) -> some View {
        HStack(spacing: 5) {
            Text(named ? "Вентилятор \(fan.id + 1)" : "\(fan.id + 1)").foregroundStyle(.secondary)
            Text("\(Int(fan.current.rounded())) → \(Int((fan.target ?? fan.current).rounded()))").monospacedDigit()
                .help("Текущие → заданные обороты")
            Text("об/мин").foregroundStyle(.tertiary)
        }.font(.system(size: 11))
    }
    private func fanControls(id: Int?) -> some View {
        let isManual = id.map { model.manualFanIDs.contains($0) } ?? model.manual
        let binding = Binding<Double>(
            get: { id.flatMap { model.fanIntensities[$0] } ?? model.intensity },
            set: { value in if let id { model.fanIntensities[id] = value } else { model.intensity = value } })
        return HStack(spacing: 6) {
            Button("Авто") { model.automatic(id: id) }.buttonStyle(.bordered).tint(isManual ? .secondary : accent)
            Button(isManual ? "Применить" : "Вручную") { model.applyManual(id: id) }
                .buttonStyle(.bordered).tint(isManual ? accent : .secondary)
                .disabled(model.manualBlockReason != nil)
                .help(model.manualBlockReason ?? "Применить заданные обороты")
            if preferences.rpmUnits {
                Slider(value: Binding(get: { model.selectedRPM(id) }, set: { value in
                    if let id { model.fanRPMs[id] = value } else { model.commonRPM = value }
                }), in: model.rpmBounds(id), step: 1).accessibilityLabel("Заданные обороты")
                Text("\(Int(model.selectedRPM(id)))").font(.system(size: 10)).monospacedDigit().frame(width: 36, alignment: .trailing)
            } else {
            Slider(value: binding, in: 0...1)
                .accessibilityLabel(id.map { "Охлаждение вентилятора \($0 + 1)" } ?? "Общее охлаждение вентиляторов")
                .help("0% — остановка, 100% — аппаратный максимум. Нажми Вручную или Применить.")
            Text("\(Int((binding.wrappedValue * 100).rounded()))%")
                .font(.system(size: 10)).monospacedDigit().frame(width: 30, alignment: .trailing)
            }
        }.controlSize(.small).disabled(model.busy)
    }

}
private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            let points = values.enumerated().map { index, value in
                CGPoint(x: geometry.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1)),
                        y: geometry.size.height * (1 - min(1, max(0, value))))
            }
            if let first = points.first, let last = points.last {
                Path { path in
                    path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                    for point in points { path.addLine(to: point) }
                    path.addLine(to: CGPoint(x: last.x, y: geometry.size.height)); path.closeSubpath()
                }.fill(LinearGradient(colors: [color.opacity(0.24), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                Path { path in
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct HistoryGraph: View {
    let points: [HistoryPoint]
    let start: TimeInterval
    let end: TimeInterval
    let ceiling: Double
    let color: Color
    var body: some View {
        Canvas { context, size in
            var lastPoint: CGPoint?
            var path = Path()
            var connected = false
            for sample in points {
                guard let value = sample.value, sample.time >= start else { connected = false; continue }
                let point = CGPoint(x: size.width * min(1, max(0, (sample.time - start) / max(1, end - start))),
                                    y: size.height * (1 - min(1, max(0, value / ceiling))))
                if connected { path.addLine(to: point) } else { path.move(to: point) }
                connected = true
                lastPoint = point
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
            if let lastPoint {
                context.fill(Path(ellipseIn: CGRect(x: lastPoint.x - 1.5, y: lastPoint.y - 1.5, width: 3, height: 3)), with: .color(color))
            }
        }
        .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
    }
}
