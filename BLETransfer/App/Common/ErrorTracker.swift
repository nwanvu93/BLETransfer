//
//  ErrorTracker.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import UIKit
import RxSwift
import RxCocoa

final class ErrorTracker: SharedSequenceConvertibleType {
    
    typealias SharingStrategy = DriverSharingStrategy
    
    private let subject = PublishSubject<Error>()
    
    func trackError<O: ObservableConvertibleType>(from source: O) -> Observable<O.Element> {
        return source.asObservable().do(onError: onError)
    }
    
    func acceptError(_ error: Error) {
        subject.onNext(error)
    }
    
    func bindError(from source: Observable<Error>) -> Disposable {
        return source.asObservable().subscribe(onNext: onError)
    }
    
    func asSharedSequence() -> SharedSequence<SharingStrategy, any Error> {
        return subject.asObservable().asDriverOnErrorJustComplete()
    }
    
    func asObservable() -> Observable<Error> {
        return subject.asObservable()
    }
    
    private func onError(_ error: Error) {
        subject.onNext(error)
    }
    
    deinit {
        subject.onCompleted()
    }
}

extension ObservableConvertibleType {
    func trackError(_ errorTracker: ErrorTracker) -> Observable<Element> {
        return errorTracker.trackError(from: self)
    }
}

extension Observable where Element == Error {
    
    func bind(to errorTracker: ErrorTracker) -> Disposable {
        return errorTracker.bindError(from: self)
    }
}
