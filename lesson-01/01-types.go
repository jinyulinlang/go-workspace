package main

import (
	"fmt"
	"strconv"
)

var isTrue bool = true
var isFalse bool = false

var a int = 10
var c int32 = 30
var b uint8 = 20
var d float32 = 40.5
var e float64 = 50.5

var p *int
var x int = 100

func main() {
	f := 3.14
	p = &x
	fmt.Println(isTrue)
	fmt.Println(isFalse)
	fmt.Println(a)
	fmt.Println(b)
	fmt.Println(c)
	fmt.Println(d)
	fmt.Println(e)
	fmt.Println(f)
	fmt.Println(*p)
	str := "123"
	var i, _ = strconv.Atoi(str)
	fmt.Println(i)

	slice()
}
func array() {
	var arr [5]int
	arr1 := [5]int{1, 2, 3, 4, 5}
	arr2 := [...]int{1, 2, 3, 4, 5}
	fmt.Println(arr)
	fmt.Println(arr1)
	fmt.Println(arr2)
}

func slice() {
	slice1 := []int{1, 2, 3, 4, 5}
	slice2 := make([]int, 5)
	slice3 := make([]int, 5, 10)
	slice1 = append(slice1, 6, 7, 8)
	slice2[0] = 2
	slice2[1] = 3
	slice2[2] = 4
	slice2[3] = 5
	slice2[4] = 6
	slice3[0] = 1
	slice3[1] = 2
	slice3[2] = 3
	slice3[3] = 4
	slice3[4] = 5
	fmt.Println(slice1)
	fmt.Println(slice2)
	fmt.Println(slice3)
	fmt.Println(cap(slice3))
}

func demonstrateSliceGrowth() {
	var s []int
	fmt.Println("开始扩容演示:")
	for i := 0; i < 20; i++ {
		oldCap := cap(s)
		s = append(s, i)
		newCap := cap(s)
		if newCap != oldCap {
			fmt.Printf("添加元素 %d: 长度= %d, 容量 %d -> %d(扩容!)\n", i, len(s), oldCap, newCap)
		} else {
			fmt.Printf("添加元素 %d:长度= %d, 容量= %d(未扩容)\n", i, len(s), cap(s))
		}

	}
}

func demostrateMap() {
	// 声明映射
	m := make(map[string]int)
	m1 := make(map[string]int)
	m2 := map[string]int{"a": 1, "b": 2}
	m["a"] = 1
	m["b"] = 2
	m1["a"] = 1
	m1["b"] = 2
	m2["c"] = 3
	fmt.Println(m)
	fmt.Println(m1)
	fmt.Println(m2)
}
