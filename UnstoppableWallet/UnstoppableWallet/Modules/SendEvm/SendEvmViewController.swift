import UIKit
import ThemeKit
import SnapKit
import SectionsTableView
import RxSwift
import RxCocoa
import EthereumKit
import CoinKit

class SendEvmViewController: ThemeViewController {
    private let evmKit: EthereumKit.Kit
    private let viewModel: SendEvmViewModel
    private let disposeBag = DisposeBag()

    private let iconImageView = UIImageView()
    private let tableView = SectionsTableView(style: .grouped)

    private let availableBalanceCell: SendAvailableBalanceCell

    private let amountCell: AmountInputCell
    private let amountCautionCell = FormCautionCell()

    private let recipientCell: RecipientAddressInputCell
    private let recipientCautionCell: RecipientAddressCautionCell

    private let buttonCell = ButtonCell()

    private var isLoaded = false
    private var keyboardShown = false

    init(evmKit: EthereumKit.Kit, viewModel: SendEvmViewModel, availableBalanceViewModel: SendAvailableBalanceViewModel, amountViewModel: AmountInputViewModel, recipientViewModel: RecipientAddressViewModel) {
        self.evmKit = evmKit
        self.viewModel = viewModel

        availableBalanceCell = SendAvailableBalanceCell(viewModel: availableBalanceViewModel)

        amountCell = AmountInputCell(viewModel: amountViewModel)

        recipientCell = RecipientAddressInputCell(viewModel: recipientViewModel)
        recipientCautionCell = RecipientAddressCautionCell(viewModel: recipientViewModel)

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "send.title".localized(viewModel.coin.code)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: iconImageView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "button.cancel".localized, style: .plain, target: self, action: #selector(didTapCancel))

        iconImageView.image = .image(coinCode: viewModel.coin.code, blockchainType: viewModel.coin.type.blockchainType)
        iconImageView.tintColor = .themeGray

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .onDrag
        tableView.sectionDataSource = self

        amountCautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

        recipientCell.onChangeHeight = { [weak self] in self?.reloadTable() }
        recipientCell.onOpenViewController = { [weak self] in self?.present($0, animated: true) }

        recipientCautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

        buttonCell.bind(style: .primaryYellow, title: "send.next_button".localized) { [weak self] in
            self?.didTapProceed()
        }

        subscribe(disposeBag, viewModel.proceedEnableDriver) { [weak self] in self?.buttonCell.isEnabled = $0 }
        subscribe(disposeBag, viewModel.amountCautionDriver) { [weak self] caution in
            self?.amountCell.set(cautionType: caution?.type)
            self?.amountCautionCell.set(caution: caution)
        }
        subscribe(disposeBag, viewModel.proceedSignal) { [weak self] in self?.openConfirm(transactionData: $0) }

        tableView.buildSections()
        isLoaded = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !keyboardShown {
            keyboardShown = true
            amountCell.becomeFirstResponder()
        }
    }

    @objc private func didTapProceed() {
        viewModel.didTapProceed()
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    private func reloadTable() {
        guard isLoaded else {
            return
        }

        UIView.animate(withDuration: 0.2) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

    private func openConfirm(transactionData: TransactionData) {
        guard let viewController = SendEvmConfirmationModule.viewController(evmKit: evmKit, transactionData: transactionData) else {
            return
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

}

extension SendEvmViewController: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        [
            Section(
                    id: "available-balance",
                    headerState: .margin(height: .margin4),
                    rows: [
                        StaticRow(
                                cell: availableBalanceCell,
                                id: "available-balance",
                                height: availableBalanceCell.cellHeight
                        )
                    ]
            ),
            Section(
                    id: "amount",
                    headerState: .margin(height: .margin8),
                    rows: [
                        StaticRow(
                                cell: amountCell,
                                id: "amount-input",
                                height: amountCell.cellHeight
                        ),
                        StaticRow(
                                cell: amountCautionCell,
                                id: "amount-caution",
                                dynamicHeight: { [weak self] width in
                                    self?.amountCautionCell.height(containerWidth: width) ?? 0
                                }
                        )
                    ]
            ),
            Section(
                    id: "recipient",
                    headerState: .margin(height: .margin16),
                    rows: [
                        StaticRow(
                                cell: recipientCell,
                                id: "recipient-input",
                                dynamicHeight: { [weak self] width in
                                    self?.recipientCell.height(containerWidth: width) ?? 0
                                }
                        ),
                        StaticRow(
                                cell: recipientCautionCell,
                                id: "recipient-caution",
                                dynamicHeight: { [weak self] width in
                                    self?.recipientCautionCell.height(containerWidth: width) ?? 0
                                }
                        )
                    ]
            ),
            Section(
                    id: "button",
                    footerState: .margin(height: .margin32),
                    rows: [
                        StaticRow(
                                cell: buttonCell,
                                id: "button",
                                height: ButtonCell.height(style: .primaryYellow)
                        )
                    ]
            )
        ]
    }

}
