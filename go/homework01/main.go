package main

import "fmt"

func main() {
	nums := []int{1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10}
	groupCount := make(map[int]int)
	for _, num := range nums {
		groupCount[num]++
	}

	for num, count := range groupCount {
		if count == 1 {
			fmt.Printf("the number: %d is unique\n", num)
		}
	}
}
