package locks

import (
	"fmt"
	"sync"
	"sync/atomic"
)

type Lock struct {
}

func (l *Lock) CalculateWithMutex() {
	var m sync.Mutex
	num := 0
	var wg sync.WaitGroup
	for i := range 10 {
		wg.Add(1)
		go func(c int) {
			defer wg.Done()
			m.Lock()
			for range 1000 {
				num++
			}
			fmt.Printf(" the %dth goroutine the number is %d\n", c, num)
			m.Unlock()
		}(i)
	}
	wg.Wait()
	fmt.Printf("with mutex the num is %d \n", num)

}
func (l *Lock) CalculateWithAtomic() {
	var wg sync.WaitGroup
	var count atomic.Int64

	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 1000 {
				count.Add(1)
			}
		}()
	}

	wg.Wait()
	fmt.Printf("with atomic the num is %d \n", count.Load())
}
