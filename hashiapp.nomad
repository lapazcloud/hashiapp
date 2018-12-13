job "hashiapp" {
  datacenters = ["dc1"]
  type = "service"

  group "app" {
    count = 5

    task "hashiapp" {
      driver = "java"

      config {
      	jar_path = "/local/hashiapp-2.0.1-jar-with-dependencies.jar"
      }

      artifact {
        source = "http://192.168.1.103:8000/hashiapp-2.0.1-jar-with-dependencies.jar"
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
