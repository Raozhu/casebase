import Foundation

enum CasebaseNetworkProxy {
    static func applyProxy(from proxyURLString: String?, to configuration: URLSessionConfiguration) {
        guard
            let proxyURLString,
            let proxyURL = URL(string: proxyURLString),
            let host = proxyURL.host
        else {
            return
        }

        let port = proxyURL.port ?? defaultPort(for: proxyURL.scheme)
        let scheme = proxyURL.scheme?.lowercased() ?? ""
        var dictionary: [AnyHashable: Any] = [:]

        switch scheme {
        case "socks", "socks5", "socks5h":
            dictionary[kCFNetworkProxiesSOCKSEnable as String] = 1
            dictionary[kCFNetworkProxiesSOCKSProxy as String] = host
            dictionary[kCFNetworkProxiesSOCKSPort as String] = port
        case "http", "https":
            dictionary[kCFNetworkProxiesHTTPEnable as String] = 1
            dictionary[kCFNetworkProxiesHTTPProxy as String] = host
            dictionary[kCFNetworkProxiesHTTPPort as String] = port
            dictionary[kCFNetworkProxiesHTTPSEnable as String] = 1
            dictionary[kCFNetworkProxiesHTTPSProxy as String] = host
            dictionary[kCFNetworkProxiesHTTPSPort as String] = port
        default:
            return
        }

        configuration.connectionProxyDictionary = dictionary
    }

    private static func defaultPort(for scheme: String?) -> Int {
        switch scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        case "socks", "socks5", "socks5h":
            return 1080
        default:
            return 0
        }
    }
}
