import Foundation

public class ImmutableObservable<T> {

    public typealias Observer = (T, T?) -> Void

    private var observers: [Int: (Observer, DispatchQueue?)] = [:]
    private var uniqueID = (0...).makeIterator()

    fileprivate let lock: Lock = Mutex()

    private var skipCount: Int?
    private var skipped = Int(0)
    
    fileprivate var _value: T {
        didSet {
            let newValue = _value
            observers.values.forEach { observer, dispatchQueue in
                notify(observer: observer, queue: dispatchQueue, value: newValue, oldValue: oldValue)
            }
        }
    }

    public var value: T {
        return _value
    }

    public init(_ value: T) {
        self._value = value
    }

    public func observe(_ queue: DispatchQueue? = nil, _ observer: @escaping Observer) -> Disposable {
        lock.lock()
        defer { lock.unlock() }
        
        let id = uniqueID.next()!

        observers[id] = (observer, queue)
        notify(observer: observer, queue: queue, value: value, oldValue: nil)
        
        let disposable = Disposable { [weak self] in
            self?.observers[id] = nil
        }

        return disposable
    }

    fileprivate func notify(observer: @escaping Observer, queue: DispatchQueue? = nil, value: T, oldValue: T? = nil) {
        
        guard self.skipped >= self.skipCount ?? 0 else { skipped += 1; return }
        
        observers.values.forEach { observer, dispatchQueue in
            if let dispatchQueue = dispatchQueue {
                dispatchQueue.async {
                    observer(value, oldValue)
                }
            } else {
                observer(value, oldValue)
            }
        }
    }
    
    public func removeAllObservers() {
        observers.removeAll()
    }
    
    public func skip(count: Int?) -> ImmutableObservable {
        self.skipCount = count
        return self
    }
    
}

public class Observable<T>: ImmutableObservable<T> {

    public override var value: T {
        get {
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
