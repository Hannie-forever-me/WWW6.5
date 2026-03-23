// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleIOU {
    address public owner; //public 修饰符会自动生成一个 owner() 只读函数，外部可通过该函数查询合约所有者。
    mapping(address => bool) public registeredFriends; //声明一个映射（类似字典）：键是 address（钱包地址），值是 bool（布尔值）,public 修饰符会生成 registeredFriends(address) 函数，可查询指定地址是否注册
    address[] public friendList; //声明一个公开的地址类型数组：存储所有已注册的朋友地址。public 修饰符会生成 friendList(uint256) 函数，可查询数组指定索引的地址
    mapping(address => uint256) public balances; //声明一个映射：键是 address（钱包地址），值是 uint256（金额）,public 修饰符会生成 balances(address) 函数，可查询指定地址的余额

    // 嵌套映射:记录债务关系
    mapping(address => mapping(address => uint256)) public debts; //嵌套映射：外层键是「债务人地址」，内层键是「债权人地址」，值是「债务金额」。
    //理解：debts[A][B] = 100 表示「A 欠 B 100 个单位的 ETH」。

    constructor() {
        owner = msg.sender; //调用当前合约地址，赋值给owner
    }

    modifier onlyOwner() {
        //自定义修饰符，复用权限检查逻辑，附加在函数上时，会先执行修饰符内的代码，再执行函数本身；
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyRegistered() {
        require(registeredFriends[msg.sender], "Not registered"); //逻辑：检查调用者是否在 registeredFriends 映射中标记为 true（已注册），未注册则拒绝执行。
        _;
    }

    // 添加朋友
    function addFriend(address _friend) public onlyOwner {
        //仅所有者修饰符
        require(!registeredFriends[_friend], "Already registered"); //检查地址是否已经注册，已经注册则报错
        registeredFriends[_friend] = true; //将该地址标记为已注册
        friendList.push(_friend); //将该地址添加到注册地址数组中
    }

    // 存入ETH到钱包
    function depositIntoWallet() public payable onlyRegistered {
        //payable：关键修饰符！标记函数「可接收 ETH」，没有这个修饰符的函数无法接收转账。
        balances[msg.sender] += msg.value; //onlyRegistered：仅已注册用户可存款。
        //msg.value：Solidity 内置全局变量，表示「调用函数时附带的 ETH 金额」（单位：wei，1 ETH = 10^18 wei）。
        //逻辑：将用户转账来的 ETH 金额，加到该用户的合约内余额 balances[msg.sender] 中。
    }

    // 记录债务(谁欠谁多少钱)
    function recordDebt(
        address _debtor,
        uint256 _amount
    ) public onlyRegistered {
        debts[_debtor][msg.sender] += _amount; //参数：_debtor（债务人地址）、_amount（债务金额）。
        //逻辑：debts[_debtor][msg.sender] += _amount → 给「债务人欠调用者（债权人）」的债务金额增加 _amount。
        //示例：A 调用此函数，参数是 B 和 100 → debts[B][A] += 100 → B 欠 A 100。
    }

    // 从钱包支付债务
    function payFromWallet(
        address _creditor,
        uint256 _amount
    ) public onlyRegistered {
        require(balances[msg.sender] >= _amount, "Insufficient balance"); //balances[msg.sender] >= _amount：检查付款人（调用者）的合约余额是否足够。
        require(debts[msg.sender][_creditor] >= _amount, "No debt to pay"); //debts[msg.sender][_creditor] >= _amount：检查付款人欠债权人的债务是否不少于要支付的金额。

        balances[msg.sender] -= _amount; //balances[msg.sender] -= _amount：付款人合约余额减少 _amount。
        balances[_creditor] += _amount; //balances[_creditor] += _amount：债权人合约余额增加 _amount。
        debts[msg.sender][_creditor] -= _amount; //debts[msg.sender][_creditor] -= _amount：付款人欠债权人的债务减少 _amount。
    }

    // 使用transfer转账
    function transferEther(
        address payable _to,
        uint256 _amount
    ) public onlyRegistered {
        //address payable _to：payable 地址才能接收 ETH 转账，普通 address 不行。
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        //转账失败会自动回滚交易。
        balances[msg.sender] -= _amount;
        _to.transfer(_amount); //_to.transfer(_amount)：Solidity 内置的转账函数，特点：固定给 2300 gas（gas 不足时转账失败）。
        //逻辑：扣减调用者的合约余额，然后将 _amount 数量的 ETH 直接转到 _to 钱包（注意：转的是合约里的 ETH，不是调用者钱包的）。
    }

    // 使用call转账(推荐)
    function transferEtherViaCall(
        address payable _to,
        uint256 _amount
    ) public onlyRegistered {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;

        (bool success, ) = _to.call{value: _amount}(""); //返回值是 (bool success, bytes memory data)：success 表示转账是否成功，data 是返回数据
        //(bool success, ) = ...：解构返回值，只取 success（忽略 data）,require(success, "Transfer failed")：检查转账是否成功，失败则回滚
        require(success, "Transfer failed");
    }

    // 提取余额
    function withdraw(uint256 _amount) public onlyRegistered {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed"); //将 _amount 数量的 ETH 从合约转到调用者自己的钱包（payable(msg.sender) 把调用者地址转为可支付地址）。
    }
}
