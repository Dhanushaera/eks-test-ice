provider "kubernetes" {
  config_path    = "~/.kube/config"

}


resource "kubernetes_namespace" "sample-jease" {
  metadata {
    name = "sample-jease"
  }
}

resource "kubernetes_deployment" "sample-jease" {
  metadata {
    name      = "jease"
    namespace = kubernetes_namespace.sample-jease.metadata.0.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "jease"
      }
    }
    template {
      metadata {
        labels = {
          app = "jease"
        }
      }
      spec {
        container {
          image = "saravak/tomcat8"
          name  = "jease-tomcat-container"
          port {
            container_port = 8080
          }
        }

      }
    }
  }
}


resource "kubernetes_service" "sample-jease" {
  metadata {
    name      = "sample-jease"
    namespace = kubernetes_namespace.sample-jease.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.sample-jease.spec.0.template.0.metadata.0.labels.app
    }
    type = "LoadBalancer"
    #session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 8080
    }
  }
}

