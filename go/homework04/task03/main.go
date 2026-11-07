package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/big"
	"os"
	"task03/counter"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

/*
*
*使用 abigen 工具自动生成 Go 绑定代码，用于与 Sepolia 测试网络上的智能合约进行交互。 具体任务

编写智能合约
使用 Solidity 编写一个简单的智能合约，例如一个计数器合约。
编译智能合约，生成 ABI 和字节码文件。
使用 abigen 生成 Go 绑定代码
安装 abigen 工具。
使用 abigen 工具根据 ABI 和字节码文件生成 Go 绑定代码。
使用生成的 Go 绑定代码与合约交互
编写 Go 代码，使用生成的 Go 绑定代码连接到 Sepolia 测试网络上的智能合约。
调用合约的方法，例如增加计数器的值。
输出调用结果。
*/

// deployCounterContract 部署计数器合约，返回合约地址和交易哈希。
func deployCounterContract(
	client *ethclient.Client,
	ctx context.Context,
	auth *bind.TransactOpts,
) (common.Address, *types.Transaction, error) {

	address, tx, _, err := counter.DeployCounter(auth, client)
	if err != nil {
		return common.Address{}, nil, err
	}
	log.Printf("Deployment submitted")
	log.Printf("deployed Contract address: %s", address.Hex())
	log.Printf("Transaction hash: %s", tx.Hash().Hex())
	// 等待部署确认
	receipt, err := bind.WaitMined(ctx, client, tx)
	if err != nil {
		return common.Address{}, nil, err
	}
	if receipt == nil {
		return common.Address{}, nil, fmt.Errorf("failed to get receipt for tx: %s", tx.Hash().Hex())
	}

	log.Printf("Transaction confirmed in block: %d", receipt.BlockNumber.Uint64())
	log.Printf(
		"Gas used: %d, gas limit: %d",
		receipt.GasUsed,
		tx.Gas(),
	)
	if receipt.Status != types.ReceiptStatusSuccessful {
		return common.Address{}, nil, fmt.Errorf(
			"deployment transaction failed: %s",
			tx.Hash().Hex(),
		)
	}
	return address, tx, nil
}

/*
export	ETH_RPC_URL=https://sepolia.infura.io/v3/xxxx

export ETH_PRIVATE_KEY=0xb775c9f30058336e0511cc09d4cae5e6xxx
*/
func main() {

	rpcUrl := os.Getenv("ETH_RPC_URL") // 替换为你的 RPC URL
	if rpcUrl == "" {
		log.Fatalf("Environment variable 'ETH_RPC_URL' is not set.")
	}
	privateKey := os.Getenv("ETH_PRIVATE_KEY") //
	if privateKey == "" {
		log.Fatalf("Environment variable 'ETH_PRIVATE_KEY' is not set.")
	}

	privateKeyECDSA, err := crypto.HexToECDSA(trim0x(privateKey)) // 去掉 "0x" 前缀
	if err != nil {
		log.Fatalf("Failed to parse private key: %v", err)
	}
	isDeployeContract := flag.Bool("deploy", false, "Deploy the counter contract")
	contactAddress := flag.String("address", "", "Counter contract address (if already deployed)")
	flag.Parse()
	// 如果 deploye是false,那么contactAddress就是合约地址 且不能为空
	if !*isDeployeContract && *contactAddress == "" {
		log.Fatal("Please provide a valid contract address or set deploy flag to true")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := ethclient.DialContext(ctx, rpcUrl)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}
	defer client.Close()
	// 获取 chainID
	chainID, err := client.ChainID(ctx)
	if err != nil {
		log.Fatalf("Failed to get chain ID: %v", err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKeyECDSA, chainID)
	if err != nil {
		log.Fatalf("Failed to create transactor: %v", err)
	}
	auth.Context = ctx
	auth.GasLimit = 0 // 设置 Gas 限制 自动估算

	// 使用客户端默认的 Gas 价格
	gasPrice, err := client.SuggestGasPrice(ctx)
	if err != nil {

	}
	auth.GasPrice = gasPrice
	if *isDeployeContract {
		// 部署计数器合约
		address, tx, err := deployCounterContract(client, ctx, auth)
		if err != nil {
			log.Fatalf("Failed to deploy counter contract: %v", err)
		}
		log.Printf("Deployment complete. Address: %s, Tx: %s", address.Hex(), tx.Hash().Hex())
		*contactAddress = address.Hex() // 更新全局变量 contractAddress
	}

	log.Printf("Counter contract deployed at address: %s", *contactAddress)
	// 加载合约地址
	contractAddr := common.HexToAddress(*contactAddress)
	// 创建合约实例
	counterInstance, err := counter.NewCounter(contractAddr, client)
	if err != nil {
		log.Fatalf("Failed to load counter contract: %v", err)
	}
	// 调用合约的 inc 方法获取当前计数值
	tx, err := counterInstance.Inc(auth)
	if err != nil {
		log.Fatalf("Failed to call Inc: %v", err)
	}
	receipt, err := bind.WaitMined(ctx, client, tx)
	if err != nil {
		log.Fatalf("Failed to wait for transaction mining: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Fatalf("inc transaction failed %s", tx.Hash().Hex())
	}
	count, err := counterInstance.X(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Fatalf("Failed to call count: %v", err)
	}
	log.Printf("Current count value after inc: %d", count)

	// 调用合约中的 incBy	方法，增加计数器的值
	tx, err = counterInstance.IncBy(auth, big.NewInt(5))
	if err != nil {
		log.Fatalf("Failed to call incBy: %v", err)
	}
	receipt, err = bind.WaitMined(ctx, client, tx)
	if err != nil {
		log.Fatalf("Failed to wait for transaction mining: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Fatalf("incBy transaction failed %s", tx.Hash().Hex())
	}
	count, err = counterInstance.X(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Fatalf("Failed to call count: %v", err)
	}
	log.Printf("Current count value after incBy: %d", count)
}

func trim0x(s string) string {
	if len(s) >= 2 && s[0:2] == "0x" {
		return s[2:]
	}
	return s
}
