job "hashiapp" {
  datacenters = ["dc1"]
  type = "service"

  update {
    stagger = "5s"
    max_parallel = 1
  }

  group "app" {
    count = 1

    task "hashiapp" {
      driver = "java"

      env {
        VAULT_TOKEN = ""
        VAULT_ADDR = "http://vault.service.consul:8200"
        DB_HOST = ""
        DB_NAME = "hashidb"
      }

      config {
      	jar_path = "/local/hashiapp-1.0-jar-with-dependencies.jar"
      }

      artifact {
        source = "https://s3.amazonaws.com/hashiapp-lapazcloud/hashiapp-1.0-jar-with-dependencies.jar"
      }
      
      resources {
        cpu = 500
        memory = 128
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hashiapp"
        tags = ["hashiapp", "lapazcloud", "urlprefix-/"]
        port = "http"
        check {
          name = "alive"
          type = "tcp"
          interval = "10s"
          timeout = "5s"
        }
      }

    }
  }
}
