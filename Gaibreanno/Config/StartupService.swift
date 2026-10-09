import Foundation
import Alamofire

final class StartupService {
    nonisolated private struct Response: Decodable {
        let code: Int
        let data: Payload?
        struct Payload: Decodable { let path: String? }
    }
    private var request: DataRequest?

    func fetchURL(completion: @escaping (URL?) -> Void) {
        request?.cancel()
        request = AF.request(StartupConfiguration.endpoint, method: .post,
                             parameters: ["username": StartupConfiguration.username],
                             encoding: URLEncoding.httpBody,
                             requestModifier: { $0.timeoutInterval = 15 })
            .validate(statusCode: 200..<300)
            .responseData(queue: .main) { response in
                guard case let .success(data) = response.result,
                      let result = try? JSONDecoder().decode(Response.self, from: data),
                      result.code == 1, let path = result.data?.path else {
                    completion(nil)
                    return
                }
                completion(StartupConfiguration.webURL(path))
            }
    }

    deinit { request?.cancel() }
}
