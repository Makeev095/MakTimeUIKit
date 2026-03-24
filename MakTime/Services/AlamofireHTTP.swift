import Foundation
import Alamofire

/// Общий `Session` Alamofire для новых запросов или постепенной миграции с `URLSession` в `APIService`.
/// Пример: `AlamofireHTTP.session.request(url, method: .get, headers: .init([.authorization(bearerToken: token)]))`
enum AlamofireHTTP {
    static let session: Session = {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return Session(configuration: config, startRequestsImmediately: true)
    }()
}
