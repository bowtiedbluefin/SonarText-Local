import Foundation

enum DistributionMethod {
    case appStore
    case direct
}

struct AppDistribution {
    
    static let current: DistributionMethod = detectDistribution()
    
    static var isAppStore: Bool {
        current == .appStore
    }
    
    static var isDirect: Bool {
        current == .direct
    }
    
    private static func detectDistribution() -> DistributionMethod {
        #if DIRECT_DISTRIBUTION
        return .direct
        #else
        return detectFromReceipt()
        #endif
    }
    
    private static func detectFromReceipt() -> DistributionMethod {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return .direct
        }
        
        guard FileManager.default.fileExists(atPath: receiptURL.path) else {
            return .direct
        }
        
        if receiptURL.lastPathComponent == "sandboxReceipt" {
            return .direct
        }
        
        return .appStore
    }
}
