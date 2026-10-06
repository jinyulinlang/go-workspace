package chanels

import (
	"fmt"
	"sync"
)

// 题目 ：编写一个程序，使用通道实现两个协程之间的通信。一个协程生成从1到10的整数，并将这些整数发送到通道中，另一个协程从通道中接收这些整数并打印出来
func GenerateReceiveDataWithoutCache() {
	var wg sync.WaitGroup
	g := make(chan int)
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 1; i <= 10; i++ {
			g <- i
		}
		close(g)
	}()
	go func() {
		defer wg.Done()
		for v := range g {
			fmt.Printf(" counsume the data %d\n", v)
		}
	}()
	wg.Wait()
	fmt.Println(" no cache ch over")

}

// 题目 ：实现一个带有缓冲的通道，生产者协程向通道中发送100个整数，消费者协程从通道中接收这些整数并打印。

func GenerateReceiveDataWithCache() {
	var wg sync.WaitGroup
	g := make(chan int, 10)
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 1; i <= 100; i++ {
			g <- i
		}
		close(g)
	}()
	go func() {
		defer wg.Done()
		for v := range g {
			fmt.Printf(" counsume the data %d\n", v)
		}
	}()
	wg.Wait()
	fmt.Println(" with cache ch over")
}
