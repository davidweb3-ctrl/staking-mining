# ETH 质押挖矿合约实现步骤

## 项目概述

本项目实现了一个基于 Foundry 的 ETH 质押挖矿合约，允许用户质押 ETH 来赚取 KK Token 奖励。奖励根据质押时长和质押数量进行公平分配。

## 详细实现步骤

### 第一步：项目初始化

1. **创建 Foundry 项目结构**
   ```bash
   # 项目已关联到 git@github.com:davidweb3-ctrl/staking-mining.git
   ```

2. **创建配置文件**
   - `foundry.toml`: Foundry 配置文件，设置 Solidity 版本、优化器等
   - `.gitignore`: Git 忽略文件配置
   - `remappings.txt`: 导入路径映射配置

### 第二步：安装依赖

1. **安装 OpenZeppelin Contracts**
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts
   ```

2. **安装 Forge Std**
   ```bash
   forge install foundry-rs/forge-std
   ```

### 第三步：实现合约接口

1. **IToken 接口** (`contracts/interfaces/IToken.sol`)
   - 继承 IERC20
   - 定义 `mint(address to, uint256 amount)` 方法

2. **IStaking 接口** (`contracts/interfaces/IStaking.sol`)
   - `stake()`: 质押 ETH
   - `unstake(uint256 amount)`: 赎回质押
   - `claim()`: 领取奖励
   - `balanceOf(address account)`: 查询质押余额
   - `earned(address account)`: 查询待领取奖励

3. **ILendingPool 接口** (`contracts/interfaces/ILendingPool.sol`)
   - 用于集成借贷市场（加分项）
   - `deposit()`: 存入 ETH
   - `withdraw(uint256 amount)`: 提取 ETH
   - `balanceOf(address account)`: 查询余额

### 第四步：实现 KK Token 合约

**文件**: `contracts/KKToken.sol`

- 继承 ERC20 和 Ownable
- 实现 IToken 接口
- 支持授权合约（如 StakingPool）铸造代币
- 使用 `minters` 映射管理铸造权限

**关键功能**:
- `addMinter(address)`: 添加铸造者
- `removeMinter(address)`: 移除铸造者
- `mint(address, uint256)`: 铸造代币

### 第五步：实现 StakingPool 核心功能

**文件**: `contracts/StakingPool.sol`

#### 5.1 核心数据结构

```solidity
struct UserInfo {
    uint256 amount;        // 质押的 ETH 数量
    uint256 stakeBlock;     // 质押时的区块号
    uint256 rewardDebt;    // 奖励债务（避免重复计算）
}
```

#### 5.2 公平分配机制

**权重计算**:
- 权重 = 质押数量 × (当前区块 - 质押区块 + 1)
- +1 是为了包含质押发生的区块

**奖励分配**:
- 每个区块产出 10 个 KK Token
- 使用 `accRewardPerWeight` 累积每单位权重的奖励
- 用户奖励 = (用户权重 × accRewardPerWeight) / 1e18 - rewardDebt

#### 5.3 核心函数实现

1. **updatePool()**
   - 更新池子状态
   - 计算自上次更新以来的奖励
   - 更新 `accRewardPerWeight`

2. **updateUserWeight(address)**
   - 更新用户权重
   - 从 `totalWeight` 中移除旧权重
   - 用于在用户操作前结算之前的权重

3. **getUserWeight(address)**
   - 计算用户当前权重
   - 权重 = amount × (block.number - stakeBlock + 1)

4. **pendingReward(address)**
   - 计算用户待领取的奖励
   - 考虑最新的池子状态

5. **stake()**
   - 质押 ETH
   - 更新池子状态
   - 更新用户权重
   - 可选：存入借贷市场

6. **unstake(uint256)**
   - 赎回质押的 ETH
   - 自动领取待领取的奖励
   - 更新权重和奖励债务

7. **claim()**
   - 领取 KK Token 奖励
   - 重置用户的质押区块（重新开始计算权重）

#### 5.4 借贷市场集成（加分项）

- 在 `stake()` 中，如果配置了借贷市场，自动存入 ETH
- 在 `unstake()` 中，从借贷市场提取 ETH
- 通过 `setLendingPool(address)` 设置借贷市场地址

### 第六步：编写测试

**文件**: `test/StakingPool.t.sol`

测试用例包括：
1. `testStake()`: 测试质押功能
2. `testUnstake()`: 测试赎回功能
3. `testClaim()`: 测试领取奖励
4. `testRewardDistribution()`: 测试奖励分配
5. `testFairDistribution()`: 测试公平分配机制
6. `testMultipleStakes()`: 测试多次质押
7. `testRewardPerBlock()`: 测试每区块奖励

### 第七步：创建部署脚本

**文件**: `script/Deploy.s.sol`

- 部署 KKToken 合约
- 部署 StakingPool 合约
- 将 StakingPool 添加为 KKToken 的铸造者

### 第八步：编译和测试

```bash
# 编译合约
forge build

# 运行测试
forge test

# 运行测试并显示详细输出
forge test -vvv

# 运行测试并显示 gas 报告
forge test --gas-report
```

## 关键技术点

### 1. 公平分配算法

使用权重系统实现公平分配：
- **权重公式**: `weight = amount × (block.number - stakeBlock + 1)`
- **总权重**: 所有用户权重的总和
- **奖励分配**: 按权重比例分配每个区块的 10 个 KK Token

### 2. 防止重复计算

使用 `rewardDebt` 机制：
- 记录用户已计算的奖励
- 新奖励 = 总奖励 - rewardDebt
- 在每次操作后更新 rewardDebt

### 3. 权重更新机制

- 在用户操作前，先更新池子状态
- 移除用户的旧权重
- 执行操作（质押/赎回/领取）
- 添加用户的新权重

### 4. 安全特性

- **ReentrancyGuard**: 防止重入攻击
- **Ownable**: 访问控制
- **Safe Transfer**: 安全的 ETH 和代币转账

## 项目结构

```
staking-mining/
├── contracts/
│   ├── interfaces/
│   │   ├── IToken.sol
│   │   ├── IStaking.sol
│   │   └── ILendingPool.sol
│   ├── KKToken.sol
│   └── StakingPool.sol
├── test/
│   └── StakingPool.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── README.md
└── IMPLEMENTATION_STEPS.md
```

## 部署说明

1. 设置环境变量：
   ```bash
   export PRIVATE_KEY=your_private_key
   ```

2. 运行部署脚本：
   ```bash
   forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --verify
   ```

## 总结

本项目成功实现了：
- ✅ ETH 质押功能
- ✅ 基于质押时长和数量的公平奖励分配
- ✅ 每区块 10 个 KK Token 的产出
- ✅ 借贷市场集成（加分项）
- ✅ 完整的测试覆盖
- ✅ 安全的合约实现

所有功能均已通过测试验证，可以安全部署使用。

