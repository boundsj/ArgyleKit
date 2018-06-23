import Foundation
import WebSocket

public typealias eventHandler = (SlackRTMClient, Response) -> Void

public enum EventType: String {
    case connect = "hello"
    case message = "message"
    case unknown
}

class HTTPService {

    static let rtmConnectURLTemplate = "https://slack.com/api/rtm.connect?token=%@"

    class func connect(token: String, completion: @escaping (_ websocketString: String) -> () ) {
        let urlString = String(format: rtmConnectURLTemplate, token)
        let url = URL(string: urlString)!
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                fatalError()
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] else {
                    fatalError()
                }

                guard let websocketURLString = json["url"] as? String else {
                    fatalError()
                }

                completion(websocketURLString)
            } catch {
                fatalError()
            }

        }
        task.resume()
    }

}

struct RTMResponse: Decodable {
    var type: String
    var channel: String?
    var eventType: EventType {
        get {
            return eventTypeFromType()
        }
    }

    private func eventTypeFromType() -> EventType {
        switch type {
        case "hello":
            return .connect
        case "message":
            return .message
        default:
            return .unknown
        }
    }
}

public struct Response {
    public var eventType: EventType
    public var json: String
    public var channel: String?
}

public class SlackRTMClient {

    private let token: String
    private let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var websocket: WebSocket?
    private var eventHandlers = [EventType: eventHandler]()
    private var messageId = 1

    public init(token: String) {
        self.token = token
    }

    public func start() {
        HTTPService.connect(token: token) { websocketString in
            print("Connecting with: \(websocketString)")

            // Parse the host and path for connection received from rtm connect
            let socket = "/websocket/"
            var hostname = websocketString.components(separatedBy: socket)[0]
            hostname = hostname[6..<hostname.count]
            let path = websocketString.components(separatedBy: socket)[1]

            do {
                self.websocket = try HTTPClient.webSocket(scheme: .wss,
                                                          hostname: hostname,
                                                          path: "\(socket)\(path)",
                    on: self.worker).wait()
            } catch {
                fatalError("Unexpected error when creating websocket")
            }

            guard let websocket = self.websocket else {
                fatalError("Websocket is not available!")
            }

            websocket.onText { ws, text in
                print(text)

                do {
                    let data = text.data(using: String.Encoding.utf8, allowLossyConversion: false)!
                    let rtmResponse = try JSONDecoder().decode(RTMResponse.self, from: data)
                    let response = Response(eventType: rtmResponse.eventType, json: text, channel: rtmResponse.channel)
                    if let handler = self.eventHandlers[rtmResponse.eventType] {
                        handler(self, response)
                    }
                } catch {
                    print("Could not parse json from RTM")
                    return
                }
            }

            websocket.onCloseCode { code in
                print("code: \(code)")
            }

            websocket.onError { (_, error) in
                print(error)
            }
        }
    }

    public func on(event: EventType, handler: @escaping eventHandler) {
        eventHandlers[event] = handler
    }

    public func sendMessage(channel: String, text: String) {
        guard let websocket = websocket else {
            fatalError("No websocket available!")
        }

        var response: Dictionary = [String: Any]()
        response["type"] = "message"
        response["channel"] = channel
        response["text"] = text
        response["id"] = self.messageId
        self.messageId += 1

        let responseJSON = try! JSONSerialization.data(withJSONObject: response)
        let string = String(data: responseJSON, encoding: String.Encoding.utf8)!
        websocket.send(text: string)
    }
}

private extension String {

    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }

}
