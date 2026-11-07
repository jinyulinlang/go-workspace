package main

import (
	"context"
	"crypto/ecdsa"
	"math/big"

	"flag"
	"log"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

/*
*
准备一个 Sepolia 测试网络的以太坊账户，并获取其私钥。
编写 Go 代码，使用 ethclient 连接到 Sepolia 测试网络。
构造一笔简单的以太币转账交易	，指定发送方、接收方和转账金额。
对交易进行签名，并将签名后的交易发送到网络。
输出交易的哈希值。

	export ETH_RPC_URL="https://sepolia.infura.io/v3/f15b139378d94492bd52d609b463c58c"
	export ETH_PRIVATE_KEY="0xb775c9f30058336e0511cc09d4cae5e6c1b455b9c498a2ab2c9decc1549a92d9"
*/
func main() {
	toAddressHex := flag.String("to", "", "recipient address")
	amountEth := flag.Float64("amount", 0, "send eth amount")
	flag.Parse()

	// 验证输入参数
	if *toAddressHex == "" || *amountEth <= 0 {
		log.Fatal("Please provide a valid recipient address and amount")
	}

	// 获取环境变量中的 ETH_RPC_URL
	rpcUrl := os.Getenv("ETH_RPC_URL")
	if rpcUrl == "" {
		log.Fatal("ETH_RPC_URL environment variable is not set")
	}
	// 获取环境变量中的 ETH_PRIVATE_KEY
	privateKeyHex := os.Getenv("ETH_PRIVATE_KEY")
	if privateKeyHex == "" {
		log.Fatal("ETH_PRIVATE_KEY environment variable is not set")
	}

	// 设置一个超时时间，防止连接长时间阻塞
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	// 使用 ethclient.DialContext 连接到 Sepolia 测试网络
	client, err := ethclient.DialContext(ctx, rpcUrl)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	// 调用 sendEth 函数发送以太币
	txHash, err := sendEth(ctx, client, privateKeyHex, *toAddressHex, *amountEth)
	if err != nil {
		log.Fatalf("Failed to send ETH: %v", err)
	}
	// 0x821f38062aaaaac15a09c414cf6c13f16f4ed4a7c329adb1bfbf6fc9458dd553
	log.Printf("Transaction sent successfully! Hash: %v", txHash)

}

func sendEth(ctx context.Context, client *ethclient.Client, privateKeyHex, toAddressHex string, amountEth float64) (any, error) {
	//  解析私钥
	privateKey, err := crypto.HexToECDSA(trim0x(privateKeyHex))
	if err != nil {
		log.Fatalf("Failed to parse private key: %v", err)
	}
	// 获取发送方地址
	publicKey := privateKey.Public()
	// 断言公钥类型为 *ecdsa.PublicKey
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("cannot assert type: publicKey is not of type *ecdsa.PublicKey")
	}
	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)

	// 解析接收方地址
	toAddress := common.HexToAddress(toAddressHex)
	// 获取chainID
	chainID, err := client.ChainID(ctx)
	if err != nil {
		return nil, err
	}
	// 获取nonce
	nonce, err := client.PendingNonceAt(ctx, fromAddress)
	if err != nil {
		return nil, err
	}
	// 将以太币金额转换为wei
	value := big.NewInt(int64(amountEth * 1e18)) // 1 ETH = 10^18 wei

	gasLimit := uint64(21000)
	// 获取当前的gas价格
	gasPriceGap, err := client.SuggestGasTipCap(ctx)
	if err != nil {
		return nil, err
	}
	head, err := client.HeaderByNumber(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to get latest block header: %v", err)
	}
	baseFee := head.BaseFee
	if baseFee == nil {
		gasPrice, err := client.SuggestGasPrice(ctx)
		if err != nil {
			log.Fatalf("Failed to get suggested gas price: %v", err)
		}
		baseFee = gasPrice
	}
	gasFeeGap := new(big.Int).Add(new(big.Int).Mul(baseFee, big.NewInt(2)), gasPriceGap)
	totalAmount := new(big.Int).Add(gasFeeGap, value)

	// 检查发送方账户余额是否足够支付交易金额和手续费
	balance, err := client.BalanceAt(ctx, fromAddress, nil)
	if err != nil {
		log.Fatalf("Failed to get account balance: %v", err)
	}
	if balance.Cmp(totalAmount) < 0 {
		log.Fatalf("Insufficient funds: balance %s, required %s", balance.String(), totalAmount.String())
	}

	// 构造交易
	tx := types.NewTransaction(nonce, toAddress, value, gasLimit, gasFeeGap, nil)

	// 签名交易
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
	if err != nil {
		return nil, err
	}

	// 发送交易
	err = client.SendTransaction(ctx, signedTx)
	if err != nil {
		return nil, err
	}

	return signedTx.Hash().Hex(), nil

}

func trim0x(s string) string {
	if len(s) >= 2 && s[0:2] == "0x" {
		return s[2:]
	}
	return s
}
