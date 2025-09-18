# Solidity基础语法与系统架构设计

**学生**：杜俊哲  
**学号**：2023111182  
**日期**：2024年9月20日  
**课程**：区块链智能合约开发

---

## 学习理念

作为一名对系统架构和设计模式有浓厚兴趣的学生，我在学习Solidity时特别关注如何构建可扩展、可维护、高内聚低耦合的智能合约系统。我相信良好的架构设计是构建企业级区块链应用的基础，因此我的学习重点是将软件工程的最佳实践应用到智能合约开发中。

---

## 第一部分：合约架构设计模式

### 1.1 代理模式与可升级合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProxyPattern
 * @dev 实现代理模式的可升级合约架构
 * @author 杜俊哲
 */

// 存储合约 - 分离数据和逻辑
contract StorageContract {
    // 存储槽布局必须保持一致
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    
    uint256 internal _totalSupply;
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    
    address internal _owner;
    bool internal _paused;
    
    // 代理相关存储
    address internal _implementation;
    address internal _admin;
    
    // 版本控制
    uint256 internal _version;
    mapping(uint256 => address) internal _implementations;
    
    // 权限控制
    mapping(bytes32 => mapping(address => bool)) internal _roles;
    mapping(bytes32 => uint256) internal _roleMembers;
    
    // 事件日志
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation, uint256 version);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
}

/**
 * @title TransparentUpgradeableProxy
 * @dev 透明代理合约实现
 */
contract TransparentUpgradeableProxy is StorageContract {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Proxy: caller is not admin");
        _;
    }
    
    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE, msg.sender), "Proxy: caller is not upgrader");
        _;
    }
    
    constructor(address implementation, address admin) {
        require(implementation != address(0), "Proxy: implementation cannot be zero");
        require(admin != address(0), "Proxy: admin cannot be zero");
        
        _implementation = implementation;
        _admin = admin;
        _version = 1;
        _implementations[1] = implementation;
        
        // 设置初始角色
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        emit ImplementationUpgraded(address(0), implementation, 1);
    }
    
    /**
     * @dev 升级实现合约
     * @param newImplementation 新的实现合约地址
     */
    function upgradeTo(address newImplementation) external onlyUpgrader {
        require(newImplementation != address(0), "Proxy: new implementation cannot be zero");
        require(newImplementation != _implementation, "Proxy: same implementation");
        require(_isContract(newImplementation), "Proxy: implementation is not a contract");
        
        address oldImplementation = _implementation;
        _implementation = newImplementation;
        _version++;
        _implementations[_version] = newImplementation;
        
        emit ImplementationUpgraded(oldImplementation, newImplementation, _version);
    }
    
    /**
     * @dev 升级实现合约并调用初始化函数
     * @param newImplementation 新的实现合约地址
     * @param data 初始化调用数据
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external payable onlyUpgrader {
        upgradeTo(newImplementation);
        
        if (data.length > 0) {
            (bool success, bytes memory returndata) = newImplementation.delegatecall(data);
            require(success, "Proxy: initialization failed");
        }
    }
    
    /**
     * @dev 回滚到指定版本
     * @param targetVersion 目标版本号
     */
    function rollbackTo(uint256 targetVersion) external onlyAdmin {
        require(targetVersion > 0 && targetVersion < _version, "Proxy: invalid version");
        require(_implementations[targetVersion] != address(0), "Proxy: version not found");
        
        address oldImplementation = _implementation;
        _implementation = _implementations[targetVersion];
        
        emit ImplementationUpgraded(oldImplementation, _implementation, targetVersion);
    }
    
    /**
     * @dev 获取当前实现合约地址
     */
    function implementation() external view returns (address) {
        return _implementation;
    }
    
    /**
     * @dev 获取当前版本号
     */
    function version() external view returns (uint256) {
        return _version;
    }
    
    /**
     * @dev 获取指定版本的实现合约地址
     */
    function getImplementation(uint256 ver) external view returns (address) {
        return _implementations[ver];
    }
    
    /**
     * @dev 更改管理员
     * @param newAdmin 新管理员地址
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Proxy: new admin cannot be zero");
        require(newAdmin != _admin, "Proxy: same admin");
        
        address oldAdmin = _admin;
        _admin = newAdmin;
        
        // 转移角色
        _revokeRole(ADMIN_ROLE, oldAdmin);
        _grantRole(ADMIN_ROLE, newAdmin);
        
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev 授予角色
     */
    function grantRole(bytes32 role, address account) external onlyAdmin {
        _grantRole(role, account);
    }
    
    /**
     * @dev 撤销角色
     */
    function revokeRole(bytes32 role, address account) external onlyAdmin {
        _revokeRole(role, account);
    }
    
    /**
     * @dev 检查是否拥有角色
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
    
    /**
     * @dev 获取角色成员数量
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256) {
        return _roleMembers[role];
    }
    
    /**
     * @dev 代理调用fallback
     */
    fallback() external payable {
        _delegate(_implementation);
    }
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {
        _delegate(_implementation);
    }
    
    /**
     * @dev 执行代理调用
     */
    function _delegate(address impl) internal {
        assembly {
            // 复制调用数据
            calldatacopy(0, 0, calldatasize())
            
            // 执行delegatecall
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            // 复制返回数据
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
    
    /**
     * @dev 内部授予角色函数
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            _roleMembers[role]++;
            emit RoleGranted(role, account, msg.sender);
        }
    }
    
    /**
     * @dev 内部撤销角色函数
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            _roleMembers[role]--;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
    
    /**
     * @dev 检查地址是否为合约
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

/**
 * @title BaseImplementation
 * @dev 基础实现合约，定义通用接口和功能
 */
abstract contract BaseImplementation is StorageContract {
    // 初始化标志
    bool internal _initialized;
    
    modifier initializer() {
        require(!_initialized, "Implementation: already initialized");
        _initialized = true;
        _;
    }
    
    modifier onlyInitialized() {
        require(_initialized, "Implementation: not initialized");
        _;
    }
    
    /**
     * @dev 获取实现合约版本
     */
    function getImplementationVersion() external pure virtual returns (string memory);
    
    /**
     * @dev 初始化函数
     */
    function initialize(bytes calldata data) external virtual initializer {
        _initialize(data);
    }
    
    /**
     * @dev 内部初始化逻辑
     */
    function _initialize(bytes calldata data) internal virtual;
    
    /**
     * @dev 升级前钩子
     */
    function _beforeUpgrade() internal virtual {}
    
    /**
     * @dev 升级后钩子
     */
    function _afterUpgrade() internal virtual {}
}
```

### 1.2 工厂模式与合约部署

```solidity
/**
 * @title ContractFactory
 * @dev 合约工厂模式实现，支持多种部署策略
 */
contract ContractFactory {
    // 部署策略枚举
    enum DeploymentStrategy {
        CREATE,
        CREATE2,
        MINIMAL_PROXY,
        BEACON_PROXY
    }
    
    // 合约模板信息
    struct ContractTemplate {
        string name;
        string version;
        address implementation;
        bytes32 bytecodeHash;
        bool active;
        uint256 deploymentCount;
        DeploymentStrategy strategy;
    }
    
    // 部署记录
    struct DeploymentRecord {
        address contractAddress;
        address deployer;
        string templateName;
        string version;
        bytes32 salt;
        uint256 timestamp;
        bytes initData;
    }
    
    mapping(string => ContractTemplate) public templates;
    mapping(address => DeploymentRecord) public deployments;
    mapping(address => address[]) public deployerContracts;
    
    string[] public templateNames;
    address[] public allDeployments;
    
    // 权限控制
    address public owner;
    mapping(address => bool) public authorizedDeployers;
    
    // 费用设置
    uint256 public deploymentFee;
    mapping(string => uint256) public templateFees;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Factory: caller is not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedDeployers[msg.sender] || msg.sender == owner, "Factory: not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedDeployers[msg.sender] = true;
    }
    
    /**
     * @dev 注册合约模板
     */
    function registerTemplate(
        string memory name,
        string memory version,
        address implementation,
        DeploymentStrategy strategy
    ) external onlyOwner {
        require(implementation != address(0), "Factory: invalid implementation");
        require(bytes(name).length > 0, "Factory: empty name");
        
        bytes32 bytecodeHash = _getBytecodeHash(implementation);
        
        ContractTemplate storage template = templates[name];
        template.name = name;
        template.version = version;
        template.implementation = implementation;
        template.bytecodeHash = bytecodeHash;
        template.active = true;
        template.strategy = strategy;
        
        // 如果是新模板，添加到列表
        if (template.deploymentCount == 0) {
            templateNames.push(name);
        }
        
        emit TemplateRegistered(name, version, implementation, strategy);
    }
    
    /**
     * @dev 部署合约
     */
    function deployContract(
        string memory templateName,
        bytes32 salt,
        bytes memory initData
    ) external payable onlyAuthorized returns (address) {
        ContractTemplate storage template = templates[templateName];
        require(template.active, "Factory: template not active");
        require(template.implementation != address(0), "Factory: template not found");
        
        // 检查费用
        uint256 requiredFee = templateFees[templateName] > 0 ? templateFees[templateName] : deploymentFee;
        require(msg.value >= requiredFee, "Factory: insufficient fee");
        
        address deployedContract;
        
        // 根据策略部署合约
        if (template.strategy == DeploymentStrategy.CREATE) {
            deployedContract = _deployWithCreate(template.implementation, initData);
        } else if (template.strategy == DeploymentStrategy.CREATE2) {
            deployedContract = _deployWithCreate2(template.implementation, salt, initData);
        } else if (template.strategy == DeploymentStrategy.MINIMAL_PROXY) {
            deployedContract = _deployMinimalProxy(template.implementation, salt);
        } else if (template.strategy == DeploymentStrategy.BEACON_PROXY) {
            deployedContract = _deployBeaconProxy(template.implementation, salt, initData);
        }
        
        require(deployedContract != address(0), "Factory: deployment failed");
        
        // 记录部署信息
        DeploymentRecord storage record = deployments[deployedContract];
        record.contractAddress = deployedContract;
        record.deployer = msg.sender;
        record.templateName = templateName;
        record.version = template.version;
        record.salt = salt;
        record.timestamp = block.timestamp;
        record.initData = initData;
        
        // 更新统计
        template.deploymentCount++;
        deployerContracts[msg.sender].push(deployedContract);
        allDeployments.push(deployedContract);
        
        emit ContractDeployed(
            deployedContract,
            msg.sender,
            templateName,
            template.version,
            salt
        );
        
        return deployedContract;
    }
    
    /**
     * @dev 预计算CREATE2地址
     */
    function computeCreate2Address(
        string memory templateName,
        bytes32 salt
    ) external view returns (address) {
        ContractTemplate memory template = templates[templateName];
        require(template.implementation != address(0), "Factory: template not found");
        
        bytes memory bytecode = _getCreationBytecode(template.implementation);
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }
    
    /**
     * @dev 批量部署合约
     */
    function batchDeploy(
        string memory templateName,
        bytes32[] memory salts,
        bytes[] memory initDataArray
    ) external payable onlyAuthorized returns (address[] memory) {
        require(salts.length == initDataArray.length, "Factory: length mismatch");
        require(salts.length > 0, "Factory: empty arrays");
        
        ContractTemplate storage template = templates[templateName];
        require(template.active, "Factory: template not active");
        
        uint256 requiredFee = templateFees[templateName] > 0 ? templateFees[templateName] : deploymentFee;
        require(msg.value >= requiredFee * salts.length, "Factory: insufficient fee");
        
        address[] memory deployedContracts = new address[](salts.length);
        
        for (uint256 i = 0; i < salts.length; i++) {
            deployedContracts[i] = _deployContract(templateName, salts[i], initDataArray[i]);
        }
        
        emit BatchDeploymentCompleted(msg.sender, templateName, deployedContracts.length);
        return deployedContracts;
    }
    
    /**
     * @dev 克隆现有合约
     */
    function cloneContract(
        address sourceContract,
        bytes32 salt,
        bytes memory initData
    ) external payable onlyAuthorized returns (address) {
        require(sourceContract != address(0), "Factory: invalid source");
        require(deployments[sourceContract].contractAddress != address(0), "Factory: source not deployed by factory");
        
        uint256 requiredFee = deploymentFee;
        require(msg.value >= requiredFee, "Factory: insufficient fee");
        
        address clonedContract = _deployMinimalProxy(sourceContract, salt);
        
        // 如果有初始化数据，调用初始化
        if (initData.length > 0) {
            (bool success,) = clonedContract.call(initData);
            require(success, "Factory: initialization failed");
        }
        
        // 记录克隆信息
        DeploymentRecord storage record = deployments[clonedContract];
        record.contractAddress = clonedContract;
        record.deployer = msg.sender;
        record.templateName = "CLONE";
        record.version = "1.0.0";
        record.salt = salt;
        record.timestamp = block.timestamp;
        record.initData = initData;
        
        deployerContracts[msg.sender].push(clonedContract);
        allDeployments.push(clonedContract);
        
        emit ContractCloned(clonedContract, sourceContract, msg.sender, salt);
        return clonedContract;
    }
    
    /**
     * @dev 设置模板状态
     */
    function setTemplateActive(string memory templateName, bool active) external onlyOwner {
        require(templates[templateName].implementation != address(0), "Factory: template not found");
        templates[templateName].active = active;
        emit TemplateStatusChanged(templateName, active);
    }
    
    /**
     * @dev 设置部署费用
     */
    function setDeploymentFee(uint256 fee) external onlyOwner {
        deploymentFee = fee;
        emit DeploymentFeeChanged(fee);
    }
    
    /**
     * @dev 设置模板特定费用
     */
    function setTemplateFee(string memory templateName, uint256 fee) external onlyOwner {
        templateFees[templateName] = fee;
        emit TemplateFeeChanged(templateName, fee);
    }
    
    /**
     * @dev 授权部署者
     */
    function authorizeDeployer(address deployer, bool authorized) external onlyOwner {
        authorizedDeployers[deployer] = authorized;
        emit DeployerAuthorizationChanged(deployer, authorized);
    }
    
    /**
     * @dev 提取费用
     */
    function withdrawFees(address payable recipient) external onlyOwner {
        require(recipient != address(0), "Factory: invalid recipient");
        uint256 balance = address(this).balance;
        require(balance > 0, "Factory: no fees to withdraw");
        
        recipient.transfer(balance);
        emit FeesWithdrawn(recipient, balance);
    }
    
    /**
     * @dev 获取部署者的合约列表
     */
    function getDeployerContracts(address deployer) external view returns (address[] memory) {
        return deployerContracts[deployer];
    }
    
    /**
     * @dev 获取所有模板名称
     */
    function getTemplateNames() external view returns (string[] memory) {
        return templateNames;
    }
    
    /**
     * @dev 获取所有部署的合约
     */
    function getAllDeployments() external view returns (address[] memory) {
        return allDeployments;
    }
    
    /**
     * @dev 获取部署统计
     */
    function getDeploymentStats() external view returns (
        uint256 totalDeployments,
        uint256 totalTemplates,
        uint256 activeTemplates
    ) {
        totalDeployments = allDeployments.length;
        totalTemplates = templateNames.length;
        
        for (uint256 i = 0; i < templateNames.length; i++) {
            if (templates[templateNames[i]].active) {
                activeTemplates++;
            }
        }
    }
    
    // 私有部署函数
    function _deployContract(
        string memory templateName,
        bytes32 salt,
        bytes memory initData
    ) private returns (address) {
        ContractTemplate storage template = templates[templateName];
        
        address deployedContract;
        
        if (template.strategy == DeploymentStrategy.CREATE) {
            deployedContract = _deployWithCreate(template.implementation, initData);
        } else if (template.strategy == DeploymentStrategy.CREATE2) {
            deployedContract = _deployWithCreate2(template.implementation, salt, initData);
        } else if (template.strategy == DeploymentStrategy.MINIMAL_PROXY) {
            deployedContract = _deployMinimalProxy(template.implementation, salt);
        } else if (template.strategy == DeploymentStrategy.BEACON_PROXY) {
            deployedContract = _deployBeaconProxy(template.implementation, salt, initData);
        }
        
        // 记录部署信息
        DeploymentRecord storage record = deployments[deployedContract];
        record.contractAddress = deployedContract;
        record.deployer = msg.sender;
        record.templateName = templateName;
        record.version = template.version;
        record.salt = salt;
        record.timestamp = block.timestamp;
        record.initData = initData;
        
        template.deploymentCount++;
        deployerContracts[msg.sender].push(deployedContract);
        allDeployments.push(deployedContract);
        
        return deployedContract;
    }
    
    function _deployWithCreate(address implementation, bytes memory initData) private returns (address) {
        bytes memory bytecode = _getCreationBytecode(implementation);
        address deployed;
        
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        
        require(deployed != address(0), "Factory: CREATE deployment failed");
        
        if (initData.length > 0) {
            (bool success,) = deployed.call(initData);
            require(success, "Factory: initialization failed");
        }
        
        return deployed;
    }
    
    function _deployWithCreate2(
        address implementation,
        bytes32 salt,
        bytes memory initData
    ) private returns (address) {
        bytes memory bytecode = _getCreationBytecode(implementation);
        address deployed;
        
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(deployed != address(0), "Factory: CREATE2 deployment failed");
        
        if (initData.length > 0) {
            (bool success,) = deployed.call(initData);
            require(success, "Factory: initialization failed");
        }
        
        return deployed;
    }
    
    function _deployMinimalProxy(address implementation, bytes32 salt) private returns (address) {
        bytes memory bytecode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(deployed != address(0), "Factory: minimal proxy deployment failed");
        return deployed;
    }
    
    function _deployBeaconProxy(
        address beacon,
        bytes32 salt,
        bytes memory initData
    ) private returns (address) {
        // 简化的信标代理实现
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(beacon, initData)
        );
        
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(deployed != address(0), "Factory: beacon proxy deployment failed");
        return deployed;
    }
    
    function _getCreationBytecode(address implementation) private pure returns (bytes memory) {
        // 这里应该返回实际的创建字节码
        // 简化实现，实际应用中需要根据具体合约生成
        return abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(implementation, msg.sender)
        );
    }
    
    function _getBytecodeHash(address implementation) private view returns (bytes32) {
        bytes memory bytecode;
        assembly {
            let size := extcodesize(implementation)
            bytecode := mload(0x40)
            mstore(0x40, add(bytecode, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(bytecode, size)
            extcodecopy(implementation, add(bytecode, 0x20), 0, size)
        }
        return keccak256(bytecode);
    }
    
    // 事件定义
    event TemplateRegistered(string indexed name, string version, address indexed implementation, DeploymentStrategy strategy);
    event ContractDeployed(address indexed contractAddress, address indexed deployer, string templateName, string version, bytes32 salt);
    event ContractCloned(address indexed clonedContract, address indexed sourceContract, address indexed deployer, bytes32 salt);
    event BatchDeploymentCompleted(address indexed deployer, string templateName, uint256 count);
    event TemplateStatusChanged(string indexed templateName, bool active);
    event DeploymentFeeChanged(uint256 newFee);
    event TemplateFeeChanged(string indexed templateName, uint256 newFee);
    event DeployerAuthorizationChanged(address indexed deployer, bool authorized);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
}

/**
 * @title BeaconProxy
 * @dev 信标代理实现
 */
contract BeaconProxy {
    address private immutable _beacon;
    
    constructor(address beacon, bytes memory data) {
        _beacon = beacon;
        if (data.length > 0) {
            (bool success,) = _implementation().delegatecall(data);
            require(success, "BeaconProxy: initialization failed");
        }
    }
    
    function _implementation() internal view returns (address) {
        return IBeacon(_beacon).implementation();
    }
    
    fallback() external payable {
        _delegate(_implementation());
    }
    
    receive() external payable {
        _delegate(_implementation());
    }
    
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

interface IBeacon {
    function implementation() external view returns (address);
}
```

---

## 第二部分：模块化架构设计

### 2.1 组件化合约系统

```solidity
/**
 * @title ModularContractSystem
 * @dev 模块化合约系统，支持插件式架构
 */

// 模块接口定义
interface IModule {
    function moduleId() external pure returns (bytes32);
    function moduleVersion() external pure returns (string memory);
    function initialize(bytes calldata data) external;
    function isInitialized() external view returns (bool);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// 模块管理器接口
interface IModuleManager {
    function installModule(address module, bytes calldata initData) external;
    function uninstallModule(bytes32 moduleId) external;
    function upgradeModule(bytes32 moduleId, address newModule, bytes calldata migrationData) external;
    function getModule(bytes32 moduleId) external view returns (address);
    function isModuleInstalled(bytes32 moduleId) external view returns (bool);
    function getInstalledModules() external view returns (bytes32[] memory);
}

/**
 * @title BaseModule
 * @dev 基础模块抽象合约
 */
abstract contract BaseModule is IModule {
    bool private _initialized;
    address public manager;
    
    modifier onlyManager() {
        require(msg.sender == manager, "BaseModule: caller is not manager");
        _;
    }
    
    modifier onlyInitialized() {
        require(_initialized, "BaseModule: not initialized");
        _;
    }
    
    constructor(address _manager) {
        require(_manager != address(0), "BaseModule: invalid manager");
        manager = _manager;
    }
    
    function initialize(bytes calldata data) external virtual override onlyManager {
        require(!_initialized, "BaseModule: already initialized");
        _initialized = true;
        _initialize(data);
        emit ModuleInitialized(moduleId(), data);
    }
    
    function isInitialized() external view override returns (bool) {
        return _initialized;
    }
    
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }
    
    function _initialize(bytes calldata data) internal virtual;
    
    event ModuleInitialized(bytes32 indexed moduleId, bytes data);
}

/**
 * @title ModuleManager
 * @dev 模块管理器实现
 */
contract ModuleManager is IModuleManager {
    // 模块信息结构
    struct ModuleInfo {
        address moduleAddress;
        string version;
        uint256 installTime;
        bool active;
        bytes32[] dependencies;
        mapping(bytes32 => bool) dependents;
    }
    
    mapping(bytes32 => ModuleInfo) private _modules;
    bytes32[] private _installedModules;
    
    // 权限控制
    address public owner;
    mapping(address => bool) public authorizedInstallers;
    
    // 模块注册表
    mapping(bytes32 => address) public moduleRegistry;
    mapping(address => bytes32) public addressToModuleId;
    
    // 依赖关系图
    mapping(bytes32 => bytes32[]) public moduleDependencies;
    mapping(bytes32 => bytes32[]) public moduleDependents;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "ModuleManager: caller is not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedInstallers[msg.sender] || msg.sender == owner, "ModuleManager: not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedInstallers[msg.sender] = true;
    }
    
    /**
     * @dev 安装模块
     */
    function installModule(address module, bytes calldata initData) external override onlyAuthorized {
        require(module != address(0), "ModuleManager: invalid module address");
        
        bytes32 moduleId = IModule(module).moduleId();
        require(!_modules[moduleId].active, "ModuleManager: module already installed");
        
        // 检查依赖关系
        bytes32[] memory dependencies = _getModuleDependencies(module);
        for (uint256 i = 0; i < dependencies.length; i++) {
            require(_modules[dependencies[i]].active, "ModuleManager: dependency not installed");
        }
        
        // 安装模块
        ModuleInfo storage moduleInfo = _modules[moduleId];
        moduleInfo.moduleAddress = module;
        moduleInfo.version = IModule(module).moduleVersion();
        moduleInfo.installTime = block.timestamp;
        moduleInfo.active = true;
        moduleInfo.dependencies = dependencies;
        
        // 更新依赖关系
        for (uint256 i = 0; i < dependencies.length; i++) {
            _modules[dependencies[i]].dependents[moduleId] = true;
            moduleDependents[dependencies[i]].push(moduleId);
        }
        
        _installedModules.push(moduleId);
        moduleRegistry[moduleId] = module;
        addressToModuleId[module] = moduleId;
        
        // 初始化模块
        if (initData.length > 0) {
            IModule(module).initialize(initData);
        }
        
        emit ModuleInstalled(moduleId, module, IModule(module).moduleVersion());
    }
    
    /**
     * @dev 卸载模块
     */
    function uninstallModule(bytes32 moduleId) external override onlyAuthorized {
        require(_modules[moduleId].active, "ModuleManager: module not installed");
        
        // 检查是否有依赖此模块的其他模块
        bytes32[] memory dependents = moduleDependents[moduleId];
        for (uint256 i = 0; i < dependents.length; i++) {
            require(!_modules[dependents[i]].active, "ModuleManager: module has active dependents");
        }
        
        address moduleAddress = _modules[moduleId].moduleAddress;
        
        // 清理依赖关系
        bytes32[] memory dependencies = _modules[moduleId].dependencies;
        for (uint256 i = 0; i < dependencies.length; i++) {
            _modules[dependencies[i]].dependents[moduleId] = false;
            _removeDependentFromArray(dependencies[i], moduleId);
        }
        
        // 标记为非活跃
        _modules[moduleId].active = false;
        
        // 从注册表中移除
        delete moduleRegistry[moduleId];
        delete addressToModuleId[moduleAddress];
        
        // 从已安装列表中移除
        _removeModuleFromArray(moduleId);
        
        emit ModuleUninstalled(moduleId, moduleAddress);
    }
    
    /**
     * @dev 升级模块
     */
    function upgradeModule(
        bytes32 moduleId,
        address newModule,
        bytes calldata migrationData
    ) external override onlyAuthorized {
        require(_modules[moduleId].active, "ModuleManager: module not installed");
        require(newModule != address(0), "ModuleManager: invalid new module address");
        require(IModule(newModule).moduleId() == moduleId, "ModuleManager: module ID mismatch");
        
        address oldModule = _modules[moduleId].moduleAddress;
        
        // 执行迁移逻辑
        if (migrationData.length > 0) {
            (bool success,) = newModule.call(migrationData);
            require(success, "ModuleManager: migration failed");
        }
        
        // 更新模块信息
        _modules[moduleId].moduleAddress = newModule;
        _modules[moduleId].version = IModule(newModule).moduleVersion();
        
        // 更新注册表
        moduleRegistry[moduleId] = newModule;
        delete addressToModuleId[oldModule];
        addressToModuleId[newModule] = moduleId;
        
        emit ModuleUpgraded(moduleId, oldModule, newModule, IModule(newModule).moduleVersion());
    }
    
    /**
     * @dev 获取模块地址
     */
    function getModule(bytes32 moduleId) external view override returns (address) {
        require(_modules[moduleId].active, "ModuleManager: module not installed");
        return _modules[moduleId].moduleAddress;
    }
    
    /**
     * @dev 检查模块是否已安装
     */
    function isModuleInstalled(bytes32 moduleId) external view override returns (bool) {
        return _modules[moduleId].active;
    }
    
    /**
     * @dev 获取所有已安装的模块
     */
    function getInstalledModules() external view override returns (bytes32[] memory) {
        bytes32[] memory activeModules = new bytes32[](_getActiveModuleCount());
        uint256 index = 0;
        
        for (uint256 i = 0; i < _installedModules.length; i++) {
            if (_modules[_installedModules[i]].active) {
                activeModules[index] = _installedModules[i];
                index++;
            }
        }
        
        return activeModules;
    }
    
    /**
     * @dev 获取模块信息
     */
    function getModuleInfo(bytes32 moduleId) external view returns (
        address moduleAddress,
        string memory version,
        uint256 installTime,
        bool active,
        bytes32[] memory dependencies
    ) {
        ModuleInfo storage info = _modules[moduleId];
        return (
            info.moduleAddress,
            info.version,
            info.installTime,
            info.active,
            info.dependencies
        );
    }
    
    /**
     * @dev 获取模块依赖
     */
    function getModuleDependencies(bytes32 moduleId) external view returns (bytes32[] memory) {
        return _modules[moduleId].dependencies;
    }
    
    /**
     * @dev 获取模块的依赖者
     */
    function getModuleDependents(bytes32 moduleId) external view returns (bytes32[] memory) {
        return moduleDependents[moduleId];
    }
    
    /**
     * @dev 批量安装模块
     */
    function batchInstallModules(
        address[] calldata modules,
        bytes[] calldata initDataArray
    ) external onlyAuthorized {
        require(modules.length == initDataArray.length, "ModuleManager: length mismatch");
        
        for (uint256 i = 0; i < modules.length; i++) {
            installModule(modules[i], initDataArray[i]);
        }
        
        emit BatchModulesInstalled(modules.length);
    }
    
    /**
     * @dev 设置授权安装者
     */
    function setAuthorizedInstaller(address installer, bool authorized) external onlyOwner {
        authorizedInstallers[installer] = authorized;
        emit AuthorizedInstallerChanged(installer, authorized);
    }
    
    /**
     * @dev 转移所有权
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ModuleManager: invalid new owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // 私有辅助函数
    function _getModuleDependencies(address module) private view returns (bytes32[] memory) {
        // 这里应该实现获取模块依赖的逻辑
        // 简化实现，返回空数组
        return new bytes32[](0);
    }
    
    function _getActiveModuleCount() private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _installedModules.length; i++) {
            if (_modules[_installedModules[i]].active) {
                count++;
            }
        }
        return count;
    }
    
    function _removeModuleFromArray(bytes32 moduleId) private {
        for (uint256 i = 0; i < _installedModules.length; i++) {
            if (_installedModules[i] == moduleId) {
                _installedModules[i] = _installedModules[_installedModules.length - 1];
                _installedModules.pop();
                break;
            }
        }
    }
    
    function _removeDependentFromArray(bytes32 dependency, bytes32 dependent) private {
        bytes32[] storage dependents = moduleDependents[dependency];
        for (uint256 i = 0; i < dependents.length; i++) {
            if (dependents[i] == dependent) {
                dependents[i] = dependents[dependents.length - 1];
                dependents.pop();
                break;
            }
        }
    }
    
    // 事件定义
    event ModuleInstalled(bytes32 indexed moduleId, address indexed moduleAddress, string version);
    event ModuleUninstalled(bytes32 indexed moduleId, address indexed moduleAddress);
    event ModuleUpgraded(bytes32 indexed moduleId, address indexed oldModule, address indexed newModule, string version);
    event BatchModulesInstalled(uint256 count);
    event AuthorizedInstallerChanged(address indexed installer, bool authorized);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
}
```

---

## 学习心得与总结

通过深入学习Solidity的系统架构设计，我深刻认识到良好的架构是构建可维护、可扩展智能合约系统的基础。作为一名注重系统架构的学生，我特别关注以下几个方面：

### 1. 分离关注点原则
在智能合约设计中，将数据存储、业务逻辑、权限控制等不同关注点分离到不同的合约中，提高了系统的可维护性和可测试性。

### 2. 可升级性设计
通过代理模式实现合约的可升级性，既保证了系统的灵活性，又维护了数据的连续性。这在企业级应用中尤为重要。

### 3. 模块化架构
模块化设计使得系统具有良好的可扩展性，新功能可以通过添加模块的方式实现，而不需要修改核心系统。

### 4. 工厂模式的应用
工厂模式在智能合约中的应用，不仅简化了合约部署流程，还提供了统一的管理和监控机制。

### 5. 依赖管理
在模块化系统中，合理的依赖管理确保了系统的稳定性和一致性，避免了循环依赖等问题。

### 6. 安全性考虑
在架构设计中，安全性是首要考虑因素。通过权限控制、输入验证、状态检查等机制，确保系统的安全性。

---

## 未来学习方向

1. **微服务架构**：探索智能合约的微服务架构设计
2. **跨链架构**：学习跨链系统的架构设计模式
3. **Layer2解决方案**：研究Layer2架构设计
4. **DeFi协议架构**：深入学习复杂DeFi协议的架构设计
5. **治理机制设计**：学习DAO治理架构的设计模式

通过这次学习，我不仅掌握了Solidity的基础语法，更重要的是学会了如何运用软件工程的最佳实践来设计智能合约系统。这种系统性的思维方式将为我未来的区块链开发工作奠定坚实的基础。

---

**学习日期**：2024年9月20日  
**总学时**：10小时  
**掌握程度**：88%  
**下次学习重点**：智能合约测试架构与持续集成