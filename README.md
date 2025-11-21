# ETH Staking Mining Contract

一个基于 Solidity 的 ETH 质押挖矿合约，允许用户质押 ETH 来赚取 KK Token 奖励。奖励根据质押时长和质押数量进行公平分配。

## 功能特性

- ✅ **质押功能**: 用户可以质押 ETH 到合约
- ✅ **赎回功能**: 用户可以赎回质押的 ETH
- ✅ **奖励领取**: 用户可以领取赚取的 KK Token 奖励
- ✅ **公平分配**: 奖励根据质押数量 × 质押时长进行分配
- ✅ **每区块奖励**: 每个区块产出 10 个 KK Token
- ✅ **借贷市场集成** (加分项): 质押的 ETH 可以存入借贷市场赚取利息

## 项目结构

```
staking-mining/
├── contracts/
│   ├── interfaces/
│   │   ├── IToken.sol          # KK Token 接口
│   │   ├── IStaking.sol        # 质押接口
│   │   └── ILendingPool.sol   # 借贷市场接口
│   ├── KKToken.sol             # KK Token 实现
│   └── StakingPool.sol         # 质押池合约
├── test/
│   └── StakingPool.t.sol       # 测试文件
├── script/
│   └── Deploy.s.sol            # 部署脚本
├── foundry.toml                # Foundry 配置
└── README.md
```

## 技术实现

### 公平分配机制

合约使用权重系统来实现公平分配：
- **权重计算**: `权重 = 质押数量 × 质押时长（区块数）`
- **奖励分配**: 每个区块产出的 10 个 KK Token 按照用户权重占总权重的比例分配

### 核心合约

1. **KKToken**: ERC20 代币，支持授权合约铸造
2. **StakingPool**: 质押池合约，实现所有质押和奖励逻辑

## 安装和设置

### 前置要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (可选，用于其他工具)

### 安装步骤

1. **安装 Foundry** (如果还没有安装):
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **安装依赖**:
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

3. **编译合约**:
```bash
forge build
```

4. **运行测试**:
```bash
forge test
```

5. **运行测试并显示详细输出**:
```bash
forge test -vvv
```

## 使用说明

### 部署合约

1. 创建 `.env` 文件并设置私钥:
```
PRIVATE_KEY=your_private_key_here
```

2. 运行部署脚本:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast --verify
```

### 合约交互

#### 质押 ETH
```solidity
stakingPool.stake{value: 1 ether}();
```

#### 赎回 ETH
```solidity
stakingPool.unstake(0.5 ether);
```

#### 领取奖励
```solidity
stakingPool.claim();
```

#### 查询质押余额
```solidity
uint256 balance = stakingPool.balanceOf(userAddress);
```

#### 查询待领取奖励
```solidity
uint256 earned = stakingPool.earned(userAddress);
```

## 测试

运行所有测试:
```bash
forge test
```

运行特定测试:
```bash
forge test --match-test testStake
```

显示 gas 报告:
```bash
forge test --gas-report
```

## 合约接口

### IStaking 接口

```solidity
interface IStaking {
    function stake() payable external;
    function unstake(uint256 amount) external;
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}
```

### IToken 接口

```solidity
interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}
```

## 安全特性

- ✅ 重入攻击保护 (ReentrancyGuard)
- ✅ 访问控制 (Ownable)
- ✅ 安全的 ETH 转账
- ✅ 防止除零错误

## 借贷市场集成 (加分项)

合约支持将质押的 ETH 存入借贷市场赚取额外利息。要启用此功能：

1. 部署或使用现有的借贷市场合约（实现 `ILendingPool` 接口）
2. 调用 `setLendingPool(address)` 设置借贷市场地址
3. 之后所有质押的 ETH 会自动存入借贷市场

## 开发步骤总结

1. ✅ 创建 Foundry 项目结构
2. ✅ 实现 KK Token 合约
3. ✅ 实现 StakingPool 核心功能 (stake, unstake, claim)
4. ✅ 实现公平分配机制（基于质押时长和数量）
5. ✅ 集成借贷市场功能（可选）
6. ✅ 编写测试文件
7. ✅ 创建部署脚本

## 许可证

MIT

