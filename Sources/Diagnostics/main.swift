import Foundation
import SystemCore
let sampler = MetricsSampler()
_ = sampler.sample()
Thread.sleep(forTimeInterval: 1)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(sampler.sample()), as: UTF8.self))
let smc = SMC()
print(String(decoding: try encoder.encode(smc.snapshot()), as: UTF8.self))
for key in ["Ftst", "F0Md", "F0md", "F1Md", "F1md", "F0Tg", "F1Tg"] { print("\(key)=\(smc.read(key).map(String.init(describing:)) ?? "unavailable")") }
