import Curses

extension Window {
    func write(_ string: String, attribute: Attribute) {
        turnOn(attribute)
        defer {
            turnOff(attribute)
        }
        write(string)
    }
}
