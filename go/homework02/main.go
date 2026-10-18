package main

import (
	"fmt"
	"homework02/locks"
	"homework02/oops"
	"homework02/tasks"
	"sync"
	"time"
)

func main() {
	// 题目 ：编写一个Go程序，定义一个函数，该函数接收一个整数指针作为参数，在函数内部将该指针指向的值增加10，然后在主函数中调用该函数并输出修改后的值
	num := 1
	add(&num)
	fmt.Printf("the number: %d\n", num)
	//题目 ：实现一个函数，接收一个整数切片的指针，将切片中的每个元素乘以2
	counts := []int{1, 2, 3, 4, 5}
	multiply(&counts)
	for _, count := range counts {
		fmt.Printf("the number*2: %d \n", count)

	}
	// coroutine()
	// // 设计一个任务调度器，接收一组任务（可以用函数表示），并使用协程并发执行这些任务，同时统计每个任务的执行时间。
	// task_scheduler()

	// // 设计一个对象，实现计算圆面积和周长的功能
	// oopDemo()
	// employeeDemo()
	// channels.GenerateReceiveDataWithoutCache()
	// channels.GenerateReceiveDataWithCache()
	lock := locks.Lock{}
	lock.CalculateWithMutex()
	lock.CalculateWithAtomic()

}

func add(num *int) {
	*num += 10
}

func multiply(nums *[]int) {
	for i := 0; i < len(*nums); i++ {
		(*nums)[i] *= 2
	}

}

func coroutine() {
	wg := sync.WaitGroup{}
	count := 10
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 1; i <= count; i++ {
			if i%2 == 1 {
				fmt.Printf("cr1:th number is odd: %d \n", i)
			}
		}
	}()
	go func() {
		defer wg.Done()
		for i := 1; i <= count; i++ {
			if i%2 == 0 {
				fmt.Printf("cr2:the number is even: %d \n", i)
			}
		}
	}()
	wg.Wait()

}

func task_scheduler() {
	s := tasks.NewScheduler()
	s.Add("Task A", func() { time.Sleep(300 * time.Millisecond) })
	s.Add("Task B", func() { time.Sleep(500 * time.Millisecond) })
	s.Add("Task C", func() { time.Sleep(700 * time.Millisecond) })
	s.Add("Task D", func() { time.Sleep(200 * time.Millisecond) })

	results := s.Run()
	for _, result := range *results {
		fmt.Printf(" %s completed in %s\n", result.Name, result.Duration)
	}
}

func oopDemo() {
	circle := oops.Circle{
		Radius: 2,
	}
	circle_a := circle.Area()
	circle_p := circle.Perimeter()
	fmt.Printf("the circle area is %f, the circle perimeter is %f\n", circle_a, circle_p)

	r := oops.Rectangle{
		Width:  2,
		Height: 3,
	}
	r_a := r.Area()
	r_p := r.Perimeter()
	fmt.Printf("the rectangle area is %f, the rectangle perimeter is %f\n", r_a, r_p)
}

func employeeDemo() {
	p := oops.Person{
		Name: "zhangsan",
		Age:  20,
	}
	e := oops.Employee{
		Person:     p,
		EmployeeID: 1,
		Salary:     10000,
	}
	e.PrintInfo()

}
