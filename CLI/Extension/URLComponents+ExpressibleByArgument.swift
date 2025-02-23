import ArgumentParser
import Foundation

extension URLComponents: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(string: argument)
        guard
            let scheme = self.scheme,
            scheme.starts(with: "http")
        else {
            return nil
        }
    }
}
