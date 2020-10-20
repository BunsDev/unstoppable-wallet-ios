import ThemeKit
import RxSwift
import RxCocoa
import SectionsTableView
import CurrencyKit
import HUD

class WalletConnectRequestViewController: ThemeViewController {
    private let viewModel: WalletConnectSendEthereumTransactionRequestViewModel
    private let feeViewModel: EthereumFeeViewModel
    private let onApprove: (Data) -> ()
    private let onReject: () -> ()

    private let tableView = SectionsTableView(style: .grouped)

    private let buttonsHolder = BottomGradientHolder()
    private let approveButton = ThemeButton()
    private let rejectButton = ThemeButton()

    private var viewItems = [WalletConnectRequestViewItem]()

    private let disposeBag = DisposeBag()

    init(viewModel: WalletConnectSendEthereumTransactionRequestViewModel, feeViewModel: EthereumFeeViewModel, onApprove: @escaping (Data) -> (), onReject: @escaping () -> ()) {
        self.viewModel = viewModel
        self.feeViewModel = feeViewModel
        self.onApprove = onApprove
        self.onReject = onReject

        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "connect".localized

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        tableView.registerCell(forClass: SendConfirmationAmountCell.self)

        tableView.registerCell(forClass: TransactionInfoFromToCell.self)
        tableView.registerCell(forClass: TransactionInfoValueCell.self)
        tableView.sectionDataSource = self
        tableView.allowsSelection = false

        view.addSubview(buttonsHolder)
        buttonsHolder.snp.makeConstraints { maker in
            maker.top.equalTo(tableView.snp.bottom).offset(-CGFloat.margin4x)
            maker.leading.trailing.bottom.equalToSuperview()
        }

        buttonsHolder.addSubview(rejectButton)
        rejectButton.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin6x)
            maker.bottom.equalToSuperview().offset(-CGFloat.margin4x)
            maker.height.equalTo(CGFloat.heightButton)
        }

        rejectButton.apply(style: .primaryGray)
        rejectButton.setTitle("button.reject".localized, for: .normal)
        rejectButton.addTarget(self, action: #selector(onTapReject), for: .touchUpInside)

        buttonsHolder.addSubview(approveButton)
        approveButton.snp.makeConstraints { maker in
            maker.top.equalToSuperview().inset(CGFloat.margin8x)
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin6x)
            maker.bottom.equalTo(rejectButton.snp.top).offset(-CGFloat.margin4x)
            maker.height.equalTo(CGFloat.heightButton)
        }

        approveButton.apply(style: .primaryYellow)
        approveButton.setTitle("button.approve".localized, for: .normal)
        approveButton.addTarget(self, action: #selector(onTapApprove), for: .touchUpInside)

        viewModel.approveEnabledDriver
                .drive(onNext: { [weak self] enabled in
                    self?.approveButton.isEnabled = enabled
                })
                .disposed(by: disposeBag)

        viewModel.rejectEnabledDriver
                .drive(onNext: { [weak self] enabled in
                    self?.rejectButton.isEnabled = enabled
                })
                .disposed(by: disposeBag)

        viewModel.errorsDriver
                .drive(onNext: { [weak self] errors in
                    // todo
                })
                .disposed(by: disposeBag)

        viewModel.sendingDriver
                .drive(onNext: { sending in
                    if sending {
                        HudHelper.instance.showSpinner(userInteractionEnabled: false)
                    }
                })
                .disposed(by: disposeBag)

        viewModel.approveSignal
                .emit(onNext: { [weak self] transactionId in
                    self?.onApprove(transactionId)
                    self?.dismiss(animated: true)
                    HudHelper.instance.showSuccess()
                })
                .disposed(by: disposeBag)

        viewItems = viewModel.viewItems
        tableView.buildSections()
    }

    @objc private func onTapApprove() {
        viewModel.approve()
    }

    @objc private func onTapReject() {
        onReject()
        dismiss(animated: true)
    }

}

extension WalletConnectRequestViewController: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        var rows = [RowProtocol]()

        rows.append(amountRow)

        rows.append(contentsOf: viewItems.map { viewItem in
            row(viewItem: viewItem)
        })

        return [Section(id: "main", rows: rows)]
    }

    private var amountRow: RowProtocol {
        let amountViewItem = viewModel.amountData

        return Row<SendConfirmationAmountCell>(
                id: "amount",
                hash: amountViewItem.primary.formattedString,
                height: SendConfirmationAmountCell.height,
                bind: { cell, _ in
                    cell.bind(primaryAmountInfo: amountViewItem.primary, secondaryAmountInfo: amountViewItem.secondary)
                }
        )
    }

    private func fromToRow(title: String, value: String, onTap: @escaping () -> ()) -> RowProtocol {
        Row<TransactionInfoFromToCell>(
                id: title,
                hash: value,
                height: .heightSingleLineCell,
                bind: { cell, _ in
                    cell.bind(title: title, value: value, onTap: onTap)
                }
        )
    }

    private func fromRow(value: String) -> RowProtocol {
        fromToRow(title: "tx_info.from_hash".localized, value: TransactionInfoAddressMapper.map(value)) { [weak self] in
        }
    }

    private func toRow(value: String) -> RowProtocol {
        fromToRow(title: "tx_info.to_hash".localized, value: TransactionInfoAddressMapper.map(value)) { [weak self] in
        }
    }

    private func inputRow(value: String) -> RowProtocol {
        fromToRow(title: "tx_info.input".localized, value: value) { [weak self] in
        }
    }

    private func valueRow(title: String, value: String?) -> RowProtocol {
        Row<TransactionInfoValueCell>(
                id: title,
                hash: value ?? "",
                height: .heightSingleLineCell,
                bind: { cell, _ in
                    cell.bind(title: title, value: value)
                }
        )
    }

    private func feeRow(coinValue: CoinValue, currencyValue: CurrencyValue?) -> RowProtocol {
        var parts = [String]()

        if let formattedCoinValue = ValueFormatter.instance.format(coinValue: coinValue) {
            parts.append(formattedCoinValue)
        }

        if let currencyValue = currencyValue, let formattedCurrencyValue = ValueFormatter.instance.format(currencyValue: currencyValue) {
            parts.append(formattedCurrencyValue)
        }

        return valueRow(
                title: "tx_info.fee".localized,
                value: parts.joined(separator: " | ")
        )
    }

    private func row(viewItem: WalletConnectRequestViewItem) -> RowProtocol {
        switch viewItem {
        case let .from(value): return fromRow(value: value)
        case let .to(value): return toRow(value: value)
        case let .input(value): return inputRow(value: value)
        }
    }

}
