# 🚗 miasoat_backend

Backend **serverless y orientado a eventos** de [misoat.co](https://misoat.co): los usuarios registran su placa y reciben un correo cuando el sistema detecta multas de tránsito (SIMIT) a su nombre.

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat-square&logo=nodedotjs&logoColor=white)
![AWS Lambda](https://img.shields.io/badge/AWS_Lambda-FF9900?style=flat-square&logo=awslambda&logoColor=white)
![Amazon SQS](https://img.shields.io/badge/Amazon_SQS-FF4F8B?style=flat-square&logo=amazonsqs&logoColor=white)
![DynamoDB](https://img.shields.io/badge/DynamoDB-4053D6?style=flat-square&logo=amazondynamodb&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)

## 🏗️ Arquitectura

```
                 POST /users
Frontend ──► API Gateway ──► users_signup (Go) ──► DynamoDB (UsersTable)
                                                          │
EventBridge (cron diario 17:00 UTC) ──► create_events (Go)┘
                                              │ un mensaje por usuario
                                              ▼
                                   SQS queue-scrapping-misoat
                                              │
                                              ▼
                               scrapping_per_user (Node.js 20)
                                              │ solo si hay multas y el usuario lo pidió
                                              ▼
                                   SQS queue-send-email-misoat
                                              │
                                              ▼
                                     send_email (Go, SMTP)
```

**Por qué así:** cada consulta corre en su propia Lambda y las colas SQS absorben los picos. Si una consulta falla, no bloquea a los demás usuarios y el mensaje se reintenta.

| Lambda | Runtime | Disparador | Responsabilidad |
|---|---|---|---|
| `users_signup` | Go (`provided.al2023`) | API Gateway | Registrar placa, correo y preferencia de notificación |
| `create_events` | Go | EventBridge (cron) | Recorrer usuarios y encolar una consulta por cada uno |
| `scrapping_per_user` | Node.js 20 | SQS | Consultar multas de la placa (hoy con datos simulados) |
| `send_email` | Go | SQS | Notificar al usuario por correo |

## ☁️ Infraestructura como código

Terraform dividido en dos capas, con estado remoto en S3:

- `infra/`: base estable (DynamoDB, colas SQS, IAM, API Gateway con CORS y regla de EventBridge)
- `app/`: las Lambdas y sus *event source mappings*, que cambian con cada despliegue

## 🔁 CI/CD (GitHub Actions, ejecución manual)

| Workflow | Para qué |
|---|---|
| `infra-deploy.yml` | Crear o actualizar la capa base |
| `first-deploy.yml` | Primer despliegue completo: infraestructura + aplicaciones |
| `deploy.yml` | Recompilar y desplegar las Lambdas |
| `nuke-infra.yml` | Destruir todo (pide escribir `CONFIRMAR`) |

## 🧑‍💻 Compilar localmente

```bash
./build_lambdas.sh   # compila las Lambdas de Go y empaqueta la de Node
```

---

Hecho por [Harold Camargo](https://haroldsoftware.com) · [LinkedIn](https://www.linkedin.com/in/haroldcamargo2002/)
