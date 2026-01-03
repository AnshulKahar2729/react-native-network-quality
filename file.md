react-native-network-quality/
├── src/
│   ├── index.ts                          (exported API)
│   ├── types.ts                          (TypeScript types)
│   └── NativeNetworkQualityModule.ts      (TurboModule spec)
├── ios/
│   └── RCTNetworkQualityModule.swift      (native implementation)
├── android/
│   └── NetworkQualityModule.kt            (native implementation)
└── package.json                           (with codegenConfig)