package main

import (
	"context"
	"flag"
	"log"
	"math/big"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
)

/*
*任务 1：区块链读写 任务目标
使用 Sepolia 测试网络实现基础的区块链交互，包括查询区块和发送交易。 具体任务

环境搭建
安装必要的开发工具，如 Go 语言环境、 go-ethereum 库。
注册 Infura 账户，获取 Sepolia 测试网络的 API Key。
查询区块
编写 Go 代码，使用 ethclient 连接到 Sepolia 测试网络。
实现查询指定区块号的区块信息，包括区块的哈希、时间戳、交易数量等。
输出查询结果到控制台。
发送交易

	export ETH_RPC_URL="https://sepolia.infura.io/v3/f15b139378d94492bd52d609c"
*/
func main() {
	// 获取环境变量中的 ETH_RPC_URL
	rpcUrl := os.Getenv("ETH_RPC_URL")
	if rpcUrl == "" {
		log.Fatal("ETH_RPC_URL environment variable is not set")
	}
	blockNumber := flag.Int64("blockNumber", 1, "Block number to query")
	flag.Parse()
	// 设置一个超时时间，防止连接长时间阻塞
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	// 使用 ethclient.DialContext 连接到 Sepolia 测试网络
	etherClient, err := ethclient.DialContext(ctx, rpcUrl)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}
	defer etherClient.Close()
	// 把 blockNumber 转换为 big.Int 类型
	blockNum := big.NewInt(*blockNumber)

	// 查询指定区块号的区块信息，包括区块的哈希、时间戳、交易数量等。
	block, err := etherClient.BlockByNumber(ctx, blockNum)
	if err != nil {
		log.Fatalf("Failed to get block: %v", err)
	}
	log.Printf("Block hash: %s", block.Hash().Hex())
	log.Printf("Block number: %d", block.Number().Uint64())
	log.Printf("Block timestamp: %d", block.Time())
	log.Printf("Block transactions: %d", len(block.Transactions()))

}
