// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

contract MultiSignatureWallet {
    event Confirmed(address indexed _owner, uint256 indexed _transactionId);
    event Revoked(address indexed _owner, uint256 indexed _transactionId);
    event Submitted(
        uint256 indexed _transactionId,
        address indexed _from,
        address _to,
        uint256 indexed _value,
        bytes _data
    );
    event Executed(
        uint256 indexed _transactionId,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data
    );
    event Deposit(address indexed _from, uint256 indexed _value);

    // Array of owners
    address[] public owners;
    uint256 public requiredNumberOfConfirmtions;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) confirmations;
    mapping(address => bool) isOwner;
    mapping(uint256 => uint256) public numberOfConfirmations;
    mapping(address => uint256) public depositorsToAmount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numberOfConfirmations;
    }

    constructor(
        address[] memory _owners,
        uint256 _requiredNumberOfConfirmtions
    ) {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        require(
            _requiredNumberOfConfirmtions <= owners.length,
            "Required number of confirmations should be less than or equal to the number of owners"
        );
        require(
            _requiredNumberOfConfirmtions > 0,
            "Required number of confirmations should be greater than 0"
        );
        requiredNumberOfConfirmtions = _requiredNumberOfConfirmtions;
    }

    //submitTransaction
    function submitTransaction(
        Transaction memory _transaction
    ) public OnlyOwner {
        transactions.push(_transaction);
        emit Submitted(
            transactions.length - 1,
            msg.sender,
            _transaction.to,
            _transaction.value,
            _transaction.data
        );
    }

    //confirmTransaction
    function confirmTransaction(
        uint256 _transactionId
    )
        public
        OnlyOwner
        TxnExists(_transactionId)
        TxnNotExecuted(_transactionId)
        TxnNotConfirmed(_transactionId)
    {
        //add the sender to the senders of the transaction

        //increment the number of confirmations of the transaction
        numberOfConfirmations[_transactionId] += 1;
        //confirm transaction
        confirmations[_transactionId][msg.sender] = true;

        emit Confirmed(msg.sender, _transactionId);
    }

    //revokeConfirmation
    function revokeConfirmation(
        uint256 _transactionId
    )
        public
        OnlyOwner
        TxnExists(_transactionId)
        TxnNotExecuted(_transactionId)
    {
        //check if the sender has confirmed the transaction
        require(
            confirmations[_transactionId][msg.sender],
            "Transaction has not been confirmed"
        );
        //decrement the number of confirmations of the transaction
        numberOfConfirmations[_transactionId] -= 1;
        //revoke confirmation
        confirmations[_transactionId][msg.sender] = false;

        emit Revoked(msg.sender, _transactionId);
    }

    //executeTransaction
    function executeTransaction(
        uint256 _transactionId
    )
        public
        OnlyOwner
        TxnExists(_transactionId)
        TxnNotExecuted(_transactionId)
    {
        //check if the number of confirmations is greater than or equal to the required number of confirmations
        require(
            numberOfConfirmations[_transactionId] >=
                requiredNumberOfConfirmtions,
            "Number of confirmations is less than the required number of confirmations"
        );
        //execute transaction
        Transaction storage txn = transactions[_transactionId];
        txn.executed = true;
        (bool success, ) = payable(txn.to).call{value: txn.value}(txn.data);
        require(success, "Transaction failed");
        emit Executed(_transactionId, msg.sender, txn.to, txn.value, txn.data);
    }

    function deposit() public payable {
        depositorsToAmount[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    //check if the transaction exists
    modifier TxnExists(uint256 _transactionId) {
        require(
            _transactionId < transactions.length,
            "Transaction does not exist"
        );
        _;
    }

    //check if the sender is an owner
    modifier OnlyOwner() {
        require(isOwner[msg.sender], "Sender is not an owner");
        _;
    }
    //check if the transaction has not been executed
    modifier TxnNotExecuted(uint256 _transactionId) {
        require(
            !transactions[_transactionId].executed,
            "Transaction has been executed"
        );
        _;
    }
    //check if the sender has not confirmed the transaction
    modifier TxnNotConfirmed(uint256 _transactionId) {
        require(
            !confirmations[_transactionId][msg.sender],
            "Transaction has been confirmed"
        );
        _;
    }
}