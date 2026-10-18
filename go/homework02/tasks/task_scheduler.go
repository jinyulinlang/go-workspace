package tasks

import (
	"fmt"
	"sync"
	"time"
)

// define the no args task func
type Task func()

type TaskResult struct {
	Index    int
	Name     string
	Duration time.Duration
}

type Scheduler struct {
	tasks []Task
	names []string
}

func NewScheduler() *Scheduler {
	return &Scheduler{}
}
func (s *Scheduler) Add(name string, task Task) {
	s.tasks = append(s.tasks, task)
	s.names = append(s.names, name)
}

func (s *Scheduler) Run() *[]TaskResult {
	// define the results arr the length  is the length of tasks
	results := make([]TaskResult, len(s.tasks))
	var wg sync.WaitGroup
	start := time.Now()
	wg.Add(len(s.tasks))
	for i, task := range s.tasks {
		go func(idx int, task Task, name string) {
			defer wg.Done()
			taskStart := time.Now()
			task()
			duration := time.Since(taskStart)
			results[idx] = TaskResult{
				Index:    idx,
				Name:     name,
				Duration: duration,
			}
		}(i, task, s.names[i])
	}
	wg.Wait()
	end := time.Since(start)
	fmt.Printf("the total consume is %d\n", end)
	return &results
}

func demo() {

}
