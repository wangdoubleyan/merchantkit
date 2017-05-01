import StoreKit

internal class StoreKitReceiptDataFetcher : NSObject {
    typealias Completion = ((Result<Data>) -> Void)
    
    private var completionHandlers = [Completion]()
    
    fileprivate var request: SKReceiptRefreshRequest?
    
    let policy: FetchPolicy
    
    init(policy: FetchPolicy) {
        self.policy = policy
        
        super.init()
    }
    
    func start() {
        switch self.policy {
            case .alwaysRefresh:
                self.startRefreshRequest()
            case .fetchElseRefresh:
                self.attemptFinishTaskFetchingLocalData(onFailure: {
                    self.startRefreshRequest()
                })
            case .onlyFetch:
                self.attemptFinishTaskFetchingLocalData(onFailure: {
                    self.finish(with: .failed(Error.receiptUnavailableWithoutUserInteraction))
                })
        }
    }
    
    func addCompletion(_ completion: @escaping Completion) {
        self.completionHandlers.append(completion)
    }
    
    func cancel() {
        self.request?.cancel()
    }
    
    fileprivate func startRefreshRequest() {
        self.request = SKReceiptRefreshRequest()
        self.request?.delegate = self
        
        self.request?.start()
    }
    
    fileprivate func attemptFinishTaskFetchingLocalData(onFailure: () -> Void) {
        if let url = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: url) {
            self.finish(with: .succeeded(data))
        } else {
            onFailure()
        }
    }
    
    fileprivate func finish(with result: Result<Data>) {
        for completion in self.completionHandlers {
            completion(result)
        }
    }
    
    enum FetchPolicy {
        case alwaysRefresh
        case fetchElseRefresh
        case onlyFetch
    }
    
    enum Error : Swift.Error {
        case receiptUnavailableWithoutUserInteraction
    }
}

extension StoreKitReceiptDataFetcher : SKRequestDelegate {
    func requestDidFinish(_ request: SKRequest) {
        self.attemptFinishTaskFetchingLocalData(onFailure: {
            fatalError("SKRequest inconsistency")
        })
    }
    
    func request(_ request: SKRequest, didFailWithError error: Swift.Error) {
        self.finish(with: .failed(error))
    }
}
