package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Kafka    KafkaConfig    `mapstructure:"kafka"`
}

type ServerConfig struct {
	Host string `mapstructure:"host"`
	Port string `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
}

type DatabaseConfig struct {
	Driver string `mapstructure:"driver"`
	DSN    string `mapstructure:"dsn"`
}

type JWTConfig struct {
	Secret string `mapstructure:"secret"`
	Expire string `mapstructure:"expire"`
}

type RedisConfig struct {
	Enabled  bool   `mapstructure:"enabled"`
	Addr     string `mapstructure:"addr"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	CacheTTL string `mapstructure:"cache_ttl"`
}

type KafkaConfig struct {
	Enabled bool     `mapstructure:"enabled"`
	Brokers []string `mapstructure:"brokers"`
	Topic   string   `mapstructure:"topic"`
}

func Load() (*Config, error) {
	v := viper.New()
	v.SetConfigType("yaml")
	configFile := os.Getenv("APP_CONFIG_FILE")
	if configFile == "" {
		configFile = "config.yaml"
	}
	v.SetConfigFile(configFile)
	v.SetEnvPrefix("APP")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	v.SetDefault("server.host", "127.0.0.1")
	v.SetDefault("server.port", "8080")
	v.SetDefault("server.mode", "debug")
	v.SetDefault("database.driver", "sqlite")
	v.SetDefault("database.dsn", "users.db")
	v.SetDefault("jwt.secret", "change-this-secret-in-production")
	v.SetDefault("jwt.expire", "24h")
	v.SetDefault("redis.enabled", false)
	v.SetDefault("redis.addr", "127.0.0.1:6379")
	v.SetDefault("redis.password", "")
	v.SetDefault("redis.db", 0)
	v.SetDefault("redis.cache_ttl", "5m")
	v.SetDefault("kafka.enabled", false)
	v.SetDefault("kafka.brokers", []string{"127.0.0.1:9092"})
	v.SetDefault("kafka.topic", "user.registered")

	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read config file %q: %w", configFile, err)
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("parse config file %q: %w", configFile, err)
	}
	if cfg.Server.Host == "" || cfg.Server.Port == "" {
		return nil, fmt.Errorf("server.host and server.port must not be empty")
	}
	if cfg.JWT.Secret == "" {
		return nil, fmt.Errorf("jwt.secret must not be empty")
	}
	if expire, err := time.ParseDuration(cfg.JWT.Expire); err != nil || expire <= 0 {
		return nil, fmt.Errorf("jwt.expire must be a positive duration")
	}
	if cfg.Database.DSN == "" {
		return nil, fmt.Errorf("database.dsn must not be empty")
	}
	switch strings.ToLower(strings.TrimSpace(cfg.Database.Driver)) {
	case "sqlite", "mysql", "postgres", "postgresql", "pgsql":
	default:
		return nil, fmt.Errorf("unsupported database driver %q (supported: sqlite, mysql, postgres)", cfg.Database.Driver)
	}
	if cfg.Redis.Enabled && cfg.Redis.CacheTTL == "" {
		return nil, fmt.Errorf("redis.cache_ttl must not be empty when Redis is enabled")
	}
	if cfg.Kafka.Enabled && (len(cfg.Kafka.Brokers) == 0 || cfg.Kafka.Topic == "") {
		return nil, fmt.Errorf("kafka.brokers and kafka.topic are required when Kafka is enabled")
	}
	return &cfg, nil
}
