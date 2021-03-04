import Foundation
import CoinKit
import RxSwift
import RxRelay
import EthereumKit
import BigInt

class SendEvmService {
    let sendCoin: Coin
    private let adapter: ISendEthereumAdapter

    private let stateRelay = PublishRelay<State>()
    private(set) var state: State = .notReady {
        didSet {
            stateRelay.accept(state)
        }
    }

    private var evmAmount: BigUInt?
    private var evmAddress: EthereumKit.Address?

    private let amountErrorRelay = PublishRelay<Error?>()
    private var amountError: Error? {
        didSet {
            amountErrorRelay.accept(amountError)
        }
    }

    private let addressErrorRelay = PublishRelay<Error?>()
    private var addressError: Error? {
        didSet {
            addressErrorRelay.accept(addressError)
        }
    }

    init(coin: Coin, adapter: ISendEthereumAdapter) {
        sendCoin = coin
        self.adapter = adapter
    }

    private func syncState() {
        if amountError == nil, addressError == nil, let amount = evmAmount, let address = evmAddress {
            let transactionData = adapter.transactionData(amount: amount, address: address)
            state = .ready(transactionData: transactionData)
        } else {
            state = .notReady
        }
    }

    private func validEvmAmount(amount: Decimal) throws -> BigUInt {
        guard let evmAmount = BigUInt(amount.roundedString(decimal: sendCoin.decimal)) else {
            throw AmountError.invalidDecimal
        }

        guard amount <= adapter.balance else {
            throw AmountError.insufficientBalance
        }

        return evmAmount
    }

}

extension SendEvmService {

    var stateObservable: Observable<State> {
        stateRelay.asObservable()
    }

    var amountErrorObservable: Observable<Error?> {
        amountErrorRelay.asObservable()
    }

}

extension SendEvmService: IAvailableBalanceService {

    var balance: Decimal {
        adapter.balance
    }

}

extension SendEvmService: IAmountInputService {

    var amount: Decimal? {
        nil
    }

    var coin: Coin? {
        sendCoin
    }

    var amountObservable: Observable<Decimal?> {
        .empty()
    }

    var coinObservable: Observable<Coin?> {
        .empty()
    }

    func onChange(amount: Decimal?) {
        if let amount = amount, amount > 0 {
            do {
                evmAmount = try validEvmAmount(amount: amount)
                amountError = nil
            } catch {
                evmAmount = nil
                amountError = error
            }
        } else {
            evmAmount = nil
            amountError = nil
        }

        syncState()
    }

}

extension SendEvmService: IRecipientAddressService {

    var initialAddress: Address? {
        nil
    }

    var error: Error? {
        addressError
    }

    var errorObservable: Observable<Error?> {
        addressErrorRelay.asObservable()
    }

    func set(address: Address?) {
        if let address = address, !address.raw.isEmpty {
            do {
                evmAddress = try EthereumKit.Address(hex: address.raw)
                addressError = nil
            } catch {
                evmAddress = nil
                addressError = error
            }
        } else {
            evmAddress = nil
            addressError = nil
        }

        syncState()
    }

    func set(amount: Decimal) {
        // todo
    }

}

extension SendEvmService {

    enum State {
        case ready(transactionData: TransactionData)
        case notReady
    }

    enum AmountError: Error {
        case invalidDecimal
        case insufficientBalance
    }

}
