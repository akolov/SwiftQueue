//
//  Lock.swift
//
//  Copyright (c) 2021 Alexander Kolov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

private protocol Locking {

    func lock()
    func unlock()

}

@available(iOS 10.0, *)
private final class UnfairLock: Locking {

    private let unfairLock: os_unfair_lock_t

    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }

}

private final class MutexLock: Locking {

    private var mutex: UnsafeMutablePointer<pthread_mutex_t>

    init() {
        mutex = .allocate(capacity: 1)

        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))

        let error = pthread_mutex_init(mutex, &attr)
        precondition(error == 0, "Failed to create pthread_mutex")
    }

    deinit {
        let error = pthread_mutex_destroy(mutex)
        precondition(error == 0, "Failed to destroy pthread_mutex")
    }

    func lock() {
        let error = pthread_mutex_lock(mutex)
        precondition(error == 0, "Failed to lock pthread_mutex")
    }

    func unlock() {
        let error = pthread_mutex_unlock(mutex)
        precondition(error == 0, "Failed to unlock pthread_mutex")
    }

}

internal class Lock {

    private let lock: Locking

    init() {
        if #available(iOS 10, *) {
            lock = UnfairLock()
        }
        else {
            lock = MutexLock()
        }
    }

    func synchronized<T>(_ closure: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return closure()
    }

    func synchronized(_ closure: () -> Void) {
        lock.lock(); defer { lock.unlock() }
        return closure()
    }

}
