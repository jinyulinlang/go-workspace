package clients

import (
	"manage-system/config"

	"github.com/segmentio/kafka-go"
)

func NewKafkaWriter(cfg config.KafkaConfig) *kafka.Writer {
	return kafka.NewWriter(kafka.WriterConfig{
		Brokers:      cfg.Brokers,
		Topic:        cfg.Topic,
		Balancer:     &kafka.LeastBytes{},
		RequiredAcks: int(kafka.RequireOne),
	})
}
