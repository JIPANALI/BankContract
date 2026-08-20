// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Bank {
    struct Account {
        uint256 balance;
        uint256 lastDeposit;
        bool exists;
    }

    enum Status {
        Active,
        Frozen
    }

    //    state variable
    // owner will be only one time updatable at the time of constructor========================================>
    address public immutable owner;
    uint256 public totalDeposits;
    Status public status;
    mapping(address => Account) public accounts;
    address[] private accountsList;
    uint private locked = 1; // at a same time only one transaction can be executed locked meaning here not executing the function and 2 means executing the function

    //event declarations
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event Transferred(
        address indexed from,
        address indexed to,
        uint256 ammount
    );
    event StatusChanged(Status newStatus);

    //custom errors which is cheaper than require string=====================>
    error NotOwner();
    error ZeroAmount();
    error InsufficientBalance(uint256 requested, uint available);
    error BankFrozen();
    error TransferFailed();
    error Reentrancy();

    //modifier things customly written to avoid using require string ====================>
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;// meeans in javascript next() will be called
    }

    modifier whenActive() {
        if (status != Status.Active) revert BankFrozen();
        _;
    }

    modifier nonReentrant() {
        if (locked == 1) {
            locked = 2;
            _;
            locked = 1;
        } else revert Reentrancy();
    }

    constructor(address _owner) {
        owner = _owner;
        status = Status.Active;
    }

    function deposit() public payable whenActive {
        if (msg.value == 0) revert ZeroAmount();

        Account storage acc = accounts[msg.sender];
        if (!acc.exists) {
            acc.exists = true;
            accountsList.push(msg.sender);
        }
        acc.balance += msg.value;
        acc.lastDeposit = block.timestamp;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value, acc.balance);
    }

    function withdraw(uint amount) external nonReentrant whenActive {
        if (amount == 0) revert ZeroAmount();

        Account storage acc = accounts[msg.sender];
        if (acc.balance < amount) {
            revert InsufficientBalance(amount, acc.balance);
        }
        acc.balance -= amount;
        totalDeposits -= amount;

        //this is actually ether send to that address// empty means no data will send to address// left side this is ok, return data in left
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function transfer(address to, uint amount) external whenActive {
        if (amount == 0) revert ZeroAmount();

        Account storage from = accounts[msg.sender];
        if (from.balance < amount) {
            revert InsufficientBalance(amount, from.balance);
        }

        Account storage dest = accounts[to];
        if (!dest.exists) {
            dest.exists = true;
            accountsList.push(to);
        }
        from.balance -= amount;
        dest.balance += amount;

        emit Transferred(msg.sender, to, amount);
    }

    //admin function======================================================>
    function setStatus(Status newStatus) external onlyOwner {
        status = newStatus;
        emit StatusChanged(newStatus);
    }

    //view/pure functions ================================================>

    function balanceOf(address user) external view returns (uint256) {
        return accounts[user].balance;
    }

    function getAccount(
        address user
    )
        external
        view
        returns (uint256 balance, uint256 lastDeposit, bool exists)
    {
        Account memory acc = accounts[user];
        return (acc.balance, acc.lastDeposit, acc.exists);
    }

    function totalAccounts() external view returns (uint256) {
        return accountsList.length;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function computeFee(
        uint256 amount,
        uint256 bps
    ) external pure returns (uint256) {
        return (amount * bps) / 10_000;
    }

    //when some one will send ether by using the contract address without any function name mension then there is special function call recive and external because it will call by the outside of the contract
    receive() external payable {
        deposit();
    }

    // Someone calls a function your contract doesn't have:
    fallback() external payable {
        revert("Function does not exist");
    }
}
