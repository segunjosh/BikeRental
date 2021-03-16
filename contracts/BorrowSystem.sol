// SPDX-License-Identifier: MIT
pragma solidity ^0.5.4;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";

contract BorrowSystem {
    // using SafeMath for uint256;

    address public owner;

    enum ProposalState {WAITING, ACCEPTED, REPAID}

    struct Proposal {
        address payable lender;
        uint256 loanId;
        ProposalState state;
        uint256 rate;
        uint256 amount;
    }

    enum LoanState {ACCEPTING, LOCKED, SUCCESSFUL, FAILED}

    struct Loan {
        address borrower;
        LoanState state;
        uint256 dueDate;
        uint256 amount;
        uint256 proposalCount;
        uint256 collected;
        uint256 startDate;
        bytes32 mortgage;
        mapping(uint256 => uint256) proposal;
    }

    Loan[] public loanList;
    Proposal[] public proposalList;

    mapping(address => uint256[]) public loanMap;
    mapping(address => uint256[]) public lendMap;

    constructor() public {
        owner = msg.sender;
    }

    function hasActiveLoan(address borrower) public view returns (bool) {
        uint256 validLoans = loanMap[borrower].length;
        if (validLoans == 0) return false;
        Loan storage obj = loanList[loanMap[borrower][validLoans - 1]];
        if (loanList[validLoans - 1].state == LoanState.ACCEPTING) return true;
        if (loanList[validLoans - 1].state == LoanState.LOCKED) return true;
        return false;
    }

    function newLoan(
        uint256 amount,
        uint256 dueDate,
        bytes32 mortgage
    ) public {
        if (hasActiveLoan(msg.sender)) return;
        uint256 currentDate = block.timestamp;
        loanList.push(
            Loan(
                msg.sender,
                LoanState.ACCEPTING,
                dueDate,
                amount,
                0,
                0,
                currentDate,
                mortgage
            )
        );
        loanMap[msg.sender].push(loanList.length - 1);
    }

    function newProposal(uint256 loanId, uint256 rate) public payable {
        if (
            loanList[loanId].borrower == address(0) ||
            loanList[loanId].state != LoanState.ACCEPTING
        ) return;
        proposalList.push(
            Proposal(msg.sender, loanId, ProposalState.WAITING, rate, msg.value)
        );
        lendMap[msg.sender].push(proposalList.length - 1);
        loanList[loanId].proposalCount++;
        loanList[loanId].proposal[loanList[loanId].proposalCount - 1] =
            proposalList.length -
            1;
    }

    function getActiveLoanId(address borrower) public view returns (uint256) {
        uint256 numLoans = loanMap[borrower].length;
        if (numLoans == 0) return (2**64 - 1);
        uint256 lastLoanId = loanMap[borrower][numLoans - 1];
        if (loanList[lastLoanId].state != LoanState.ACCEPTING)
            return (2**64 - 1);
        return lastLoanId;
    }

    function revokeMyProposal(uint256 id) public {
        uint256 proposeId = lendMap[msg.sender][id];
        if (proposalList[proposeId].state != ProposalState.WAITING) return;
        uint256 loanId = proposalList[proposeId].loanId;
        if (loanList[loanId].state == LoanState.ACCEPTING) {
            // Lender wishes to revoke his ETH when proposal is still WAITING
            proposalList[proposeId].state = ProposalState.REPAID;
            msg.sender.transfer(proposalList[proposeId].amount);
        } else if (loanList[loanId].state == LoanState.LOCKED) {
            // The loan is locked/accepting and the due date passed : transfer the mortgage
            if (loanList[loanId].dueDate < now) return;
            loanList[loanId].state = LoanState.FAILED;
            for (uint256 i = 0; i < loanList[loanId].proposalCount; i++) {
                uint256 numI = loanList[loanId].proposal[i];
                if (proposalList[numI].state == ProposalState.ACCEPTED) {
                    // transfer mortgage
                }
            }
        }
    }

    function lockLoan(uint256 loanId) public {
        //contract will send money to msg.sender
        //states of proposals would be finalized, not accepted proposals would be reimbursed
        if (loanList[loanId].state == LoanState.ACCEPTING) {
            loanList[loanId].state = LoanState.LOCKED;
            for (uint256 i = 0; i < loanList[loanId].proposalCount; i++) {
                uint256 numI = loanList[loanId].proposal[i];
                if (proposalList[numI].state == ProposalState.ACCEPTED) {
                    msg.sender.transfer(proposalList[numI].amount); //Send to borrower
                } else {
                    proposalList[numI].state = ProposalState.REPAID;
                    proposalList[numI].lender.transfer(
                        proposalList[numI].amount
                    ); //Send back to lender
                }
            }
        } else return;
    }

    //Amount to be Repaid
    function getRepayValue(uint256 loanId) public view returns (uint256) {
        if (loanList[loanId].state == LoanState.LOCKED) {
            uint256 time = loanList[loanId].startDate;
            uint256 finalamount = 0;
            for (uint256 i = 0; i < loanList[loanId].proposalCount; i++) {
                uint256 numI = loanList[loanId].proposal[i];
                if (proposalList[numI].state == ProposalState.ACCEPTED) {
                    uint256 original = proposalList[numI].amount;
                    uint256 rate = proposalList[numI].rate;
                    uint256 blockTime = block.timestamp;
                    uint256 interest =
                        (original * rate * (blockTime - time)) /
                            (365 * 24 * 60 * 60 * 100);
                    finalamount += interest;
                    finalamount += original;
                }
            }
            return finalamount;
        } else return (2**64 - 1);
    }

    function repayLoan(uint256 loanId) public payable {
        uint256 blockTime = block.timestamp;
        uint256 toBePaid = getRepayValue(loanId);
        uint256 time = loanList[loanId].startDate;
        uint256 paid = msg.value;
        if (paid >= toBePaid) {
            uint256 remain = paid - toBePaid;
            loanList[loanId].state = LoanState.SUCCESSFUL;
            for (uint256 i = 0; i < loanList[loanId].proposalCount; i++) {
                uint256 numI = loanList[loanId].proposal[i];
                if (proposalList[numI].state == ProposalState.ACCEPTED) {
                    uint256 original = proposalList[numI].amount;
                    uint256 rate = proposalList[numI].rate;
                    uint256 interest =
                        (original * rate * (blockTime - time)) /
                            (365 * 24 * 60 * 60 * 100);
                    uint256 finalamount = interest + original;
                    proposalList[numI].lender.transfer(finalamount);
                    proposalList[numI].state = ProposalState.REPAID;
                }
            }
            msg.sender.transfer(remain);
        } else {
            msg.sender.transfer(paid);
        }
    }

    function acceptProposal(uint256 proposeId) public {
        uint256 loanId = getActiveLoanId(msg.sender);
        if (loanId == (2**64 - 1)) return;
        Proposal storage pObj = proposalList[proposeId];
        if (pObj.state != ProposalState.WAITING) return;

        Loan storage lObj = loanList[loanId];
        if (lObj.state != LoanState.ACCEPTING) return;

        if (lObj.collected + pObj.amount <= lObj.amount) {
            loanList[loanId].collected += pObj.amount;
            proposalList[proposeId].state = ProposalState.ACCEPTED;
        }
    }

    function totalProposalsBy(address lender) public view returns (uint256) {
        return lendMap[lender].length;
    }

    function getProposalAtPosFor(address lender, uint256 pos)
        public
        view
        returns (
            address,
            uint256,
            ProposalState,
            uint256,
            uint256,
            uint256,
            uint256,
            bytes32
        )
    {
        Proposal storage prop = proposalList[lendMap[lender][pos]];
        return (
            prop.lender,
            prop.loanId,
            prop.state,
            prop.rate,
            prop.amount,
            loanList[prop.loanId].amount,
            loanList[prop.loanId].dueDate,
            loanList[prop.loanId].mortgage
        );
    }

    // BORROWER ACTIONS AVAILABLE

    function totalLoansBy(address borrower) public view returns (uint256) {
        return loanMap[borrower].length;
    }

    function getLoanDetailsByAddressPosition(address borrower, uint256 pos)
        public
        view
        returns (
            LoanState,
            uint256,
            uint256,
            uint256,
            uint256,
            bytes32
        )
    {
        Loan storage obj = loanList[loanMap[borrower][pos]];
        return (
            obj.state,
            obj.dueDate,
            obj.amount,
            obj.collected,
            loanMap[borrower][pos],
            obj.mortgage
        );
    }

    function getLastLoanState(address borrower)
        public
        view
        returns (LoanState)
    {
        uint256 loanLength = loanMap[borrower].length;
        if (loanLength == 0) return LoanState.SUCCESSFUL;
        return loanList[loanMap[borrower][loanLength - 1]].state;
    }

    function getLastLoanDetails(address borrower)
        public
        view
        returns (
            LoanState,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 loanLength = loanMap[borrower].length;
        Loan storage obj = loanList[loanMap[borrower][loanLength - 1]];
        return (
            obj.state,
            obj.dueDate,
            obj.amount,
            obj.proposalCount,
            obj.collected
        );
    }

    function getProposalDetailsByLoanIdPosition(uint256 loanId, uint256 numI)
        public
        view
        returns (
            ProposalState,
            uint256,
            uint256,
            uint256,
            address
        )
    {
        Proposal storage obj = proposalList[loanList[loanId].proposal[numI]];
        return (
            obj.state,
            obj.rate,
            obj.amount,
            loanList[loanId].proposal[numI],
            obj.lender
        );
    }

    function numTotalLoans() public view returns (uint256) {
        return loanList.length;
    }
}
