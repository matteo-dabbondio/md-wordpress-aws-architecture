# WordPress on AWS

Production-oriented WordPress platform on AWS: multi-AZ, infrastructure as code, edge security, and a clean separation between platform and application releases.

**Language / Lingua:** [Italiano](#italiano) · [English](#english)

---

# Italiano

## Indice

1. [Contesto](#1-contesto)
2. [Architettura](#2-architettura)
3. [Stack](#3-stack)
4. [Scelte chiave e trade-off](#4-scelte-chiave-e-trade-off)
5. [Prerequisiti](#5-prerequisiti)
6. [Come utilizzare il progetto](#6-come-utilizzare-il-progetto)
7. [Costi](#7-costi)
8. [Evolutive e ottimizzazioni](#8-evolutive-e-ottimizzazioni)

---

## 1. Contesto

Questo repository fornisce un’infrastruttura AWS completa per ospitare WordPress in modo **sicuro**, **performante**, **fault-tolerant** e **scalabile**, gestita interamente con **Terraform**.

L’obiettivo è quello di fornire una baseline adatta a un workload editoriale o corporate: edge protetto (CloudFront + WAF), compute containerizzato su ECS Fargate, dati su Aurora MySQL, object cache su Valkey, filesystem condiviso su EFS, media su S3. La versione del CMS è parametrizzabile a build time; l’infrastruttura resta indipendente dal ciclo di release applicativo.

L’ambiente di riferimento nel codice è `dev` (regione `eu-central-1`). La struttura a moduli è pensata per estendersi a più ambienti senza riscrivere lo stack.

---

## 2. Architettura

### Overview

La soluzione è una piattaforma WordPress multi-AZ su AWS, modellata a layer e provisionata con Terraform. L’accesso pubblico avviene esclusivamente attraverso Content Delivery Network (CDN) edge fornita da CloudFront; il compute applicativo resta in subnet private; i dati persistenti (database e cache) in subnet isolate senza route verso Internet.

**Percorso di una richiesta**

1. Il client raggiunge CloudFront in HTTPS (`*.cloudfront.net` di default). Il WebACL WAF (modalità BLOCK) filtra il traffico prima che raggiunga l’origin.
2. Le richieste dinamiche (HTML/PHP e path non cacheabili) sono inoltrate all’Application Load Balancer nelle subnet pubbliche. L’origin è HTTP sulla porta 80: senza dominio custom non viene emesso un certificato ACM sull’ALB; la terminazione TLS resta su CloudFront.
3. L’ALB distribuisce il carico sui task ECS Fargate (Apache + PHP 8.3) nelle subnet private, su due Availability Zone, con health check `GET /`.
4. Ogni task monta lo stesso filesystem EFS su `/var/www/html` (document root condiviso), così plugin e theme installati da wp-admin restano coerenti tra le istanze (WordPress è un'applicazione stateful).
5. Il runtime parla con Aurora MySQL (writer + reader) e con Valkey Serverless per l’object cache (una volta attivato il plugin Redis Object Cache), entrambi raggiungibili solo dagli Security Group dei consumer ECS.
6. I media, una volta attivato WP Offload Media, risiedono su un bucket S3 privato e vengono erogati dalla stessa distribuzione CloudFront tramite Origin Access Control. Il traffico verso S3 dalla VPC usa un Gateway VPC Endpoint (senza attraversare i NAT).

**Separazione piattaforma / applicazione**

Terraform costruisce e collega la piattaforma (rete, ALB, ECS, Aurora, Valkey, EFS, S3, ECR, CloudFront/WAF, secret di wiring). L’immagine WordPress è un artefatto separato: gestito tramite build Docker con `WORDPRESS_VERSION` parametrizzabile, push su ECR con tag di deploy `app` (fisso nella soluzione attuale allo scopo di non modificare la task definition in fase di deploy dell'applicativo), poi rolling del service ECS.

L’utente amministratore del CMS nasce dal wizard WordPress al primo accesso, non da setup Terraform.

**Organizzazione della rete**

La VPC (`10.0.0.0/16` di default) è suddivisa in tre tier su due AZ: pubbliche (ALB, NAT), private (ECS, mount target EFS) e isolate (Aurora, Valkey). L’egress dai privati passa da due NAT Gateway. I moduli Terraform restano indipendenti tra loro: ogni risorsa possiede il proprio Security Group; le regole cross-modulo e la policy IAM del filesystem EFS sono composte nel root `environments/dev`, per evitare dipendenze cicliche.

Architettura infrastrutturale:

![Diagramma architetturale WordPress su AWS](./docs/WP_AWS_architecture.png)

### Flusso di rete e sicurezza a tier


| Tier     | Ruolo            | Controlli principali                                                                             |
| -------- | ---------------- | ------------------------------------------------------------------------------------------------ |
| Edge     | CloudFront + WAF | Terminazione TLS, caching statici/media, WAF per sicurezza perimetrale                           |
| Pubblico | ALB              | Solo traffico atteso dal path edge verso la origin, con SG dedicato                              |
| Privato  | ECS Fargate, EFS | Nessun accesso diretto da Internet; egress controllato via NAT Gateway (es. per download plugin) |
| Isolato  | Aurora, Valkey   | Nessuna route Internet; ingress solo dagli SG dei consumer (ECS)                                 |


Ogni Security Group è di proprietà del modulo della risorsa (`alb`, `ecs`, `database`, `cache`, `efs`). Le regole cross-modulo e la file system policy EFS↔task role ECS sono composte nel root `terraform/environments/dev` (`sg_rules_composer.tf`, `efs_policy.tf`).

### Compute e scaling

- **Task**: singolo container `wordpress-apache` (pattern ufficiale Docker Hub: [https://hub.docker.com/_/wordpress](https://hub.docker.com/_/wordpress)), CPU/memoria calibrabili (default 512 / 1024).
- **Service**: minimo 2 task (una per AZ) per garantire alta affidabilità, capacity provider Fargate Standard e Fargate Spot per lo scaling, riducendo i costi negli ambienti inferiori a produzione.
- **Autoscaling**: target tracking su CPU e request count ALB.
- **Health check ALB**: `GET /` (matcher `200` / `301` / `302`); l’immagine Hub non espone un endpoint `/healthz` dedicato "leggero".

### Dati e secret

- **Aurora**: password master gestita da RDS in Secrets Manager (`manage_master_user_password`), con rotazione.
- **Valkey**: autenticazione RBAC; credenziali in Secrets Manager nel modulo `cache`.
- **WordPress**: AUTH_KEY e salts richiesti dall’immagine Docker, centralizzati in Secrets Manager (modulo `ecs`); l’utente admin CMS non è gestito da Terraform.
- **Encryption at rest**: chiavi AWS-managed nella baseline.

### Struttura del repository

```
.
├── docker/                          # Dockerfile (immagine ufficiale WP Apache + build-arg versione)
├── docs/                            # Diagramma architetturale
├── terraform/
│   ├── modules/
│   │   ├── networking/              # VPC, subnet, NAT ×2, S3 Gateway Endpoint
│   │   ├── efs/                     # Filesystem condiviso + access point
│   │   ├── storage/                 # Bucket media e logs
│   │   ├── database/                # Aurora Serverless v2 + SG + secret master
│   │   ├── cache/                   # Valkey Serverless + RBAC/Secrets + SG
│   │   ├── ecr/                     # Repository immagini
│   │   ├── alb/                     # Load balancer + target group + SG
│   │   ├── cdn/                     # CloudFront + WAF (+ policy bucket media OAC)
│   │   └── ecs/                     # Cluster, task, service, IAM, autoscaling, salts
│   ├── environments/dev/            # Composition root (wiring moduli + SG + EFS policy)
│   └── scripts/init-backend.sh      # Bootstrap bucket S3 per lo state Terraform
└── README.md
```

Naming: `{project}-{environment}-{resource}` (es. `wordpress-dev-vpc`). Tag comuni: `Project`, `Environment`, `ManagedBy=Terraform`, `Repository`, `Owner`.

---

## 3. Stack


| Layer      | Tecnologia/Servizio                                      | Note                                                                     |
| ---------- | -------------------------------------------------------- | ------------------------------------------------------------------------ |
| CMS        | WordPress (build-arg `WORDPRESS_VERSION`, default `7.0`) | Versione CMS parametrizzabile, con tag di deploy su ECR ad ora fisso     |
| Runtime    | Apache + mod_php (PHP 8.3)                               | Immagine ufficiale Docker Hub, thin wrapper per parametrizzare versione  |
| Compute    | ECS Fargate                                              | Task single-container, 2 AZ                                              |
| Database   | Aurora MySQL 8.0 Serverless v2                           | Writer + reader Multi-AZ                                                 |
| Cache      | ElastiCache Valkey Serverless                            | Object cache (plugin scaricato da wp-admin al primo accesso applicativo) |
| CDN / edge | CloudFront + WAF                                         | TLS su `*.cloudfront.net`                                                |
| Media      | S3 privato + CloudFront OAC                              | Plugin WP Offload Media da wp-admin al primo accesso applicativo         |
| App FS     | EFS Multi-AZ su `/var/www/html`                          | Plugin/theme condivisi tra task                                          |
| Registry   | Amazon ECR                                               | Tag di deploy mutabile `app`                                             |
| IaC        | Terraform ≥ 1.10, AWS provider ~> 6.0                    | Backend S3 + `use_lockfile`                                              |


---

## 4. Scelte chiave e trade-off

Di seguito i razionali delle scelte principali: soluzione adottata, confronto con le alternative più rilevanti e trade-off eventualmente accettati.

### Compute: ECS Fargate

Il compute applicativo gira su **ECS Fargate** (serverless), con almeno due task su Availability Zone distinte e capacity provider che combinano Fargate Standard (base stabile) e Fargate Spot (scaling dei picchi a costo contenuto). Il service usa autoscaling su CPU e request count ALB. La soluzione resta compatibile con l’immagine Docker ufficiale di WordPress con Server Apache, senza richiedere un runtime custom.

Rispetto a una flotta **EC2** con Autoscale e AMI da gestire, Fargate elimina patching OS e capacity planning degli host: per un CMS containerizzato standard il guadagno operativo è elevato. **EKS** resterebbe una scelta valida in presenza di molti servizi e di un ecosistema Kubernetes già consolidato; per un singolo workload WordPress introdurrebbe un piano di controllo e una complessità non giustificati.

Si accetta un controllo più limitato su kernel e host, e i vincoli tipici di Fargate (CPU/memoria a step fissi) nel capacity planning.

### Runtime nel task: Apache + mod_php in un solo container

Il task espone un unico container basato sull’immagine ufficiale `wordpress:*-php8.3-apache`, con wiring tramite variabili `WORDPRESS`_* (database, URL pubblico, salts, target Valkey/S3). È il pattern supportato da Docker Hub e può runnare su singola tas (monolitico autocontenuto).

Alternative come **nginx + php-fpm** in multi-container o un reverse proxy custom nel task darebbero più flessibilità di tuning, a fronte di più superficie operativa e di un contratto applicativo meno allineato all’immagine Hub. Prestazioni e scala sono affidate a CloudFront, Valkey e autoscaling ECS, non alla complessità interna del task.

Il trade-off è la mancanza di una separazione fine-grained tra web server e PHP all’interno del task; il tuning avanzato di nginx/php-fpm resta fuori perimetro.

### Database: Aurora MySQL Serverless v2

I dati persistono su **Aurora MySQL 8.0 Serverless v2** con writer e reader Multi-AZ. Si ottengono storage distribuito, failover rapido e backup continuo tipici di Aurora, con capacità (ACU) che scala col carico reale. La master password è gestita da RDS in Secrets Manager, con rotazione; l’accesso resta confinato alle subnet isolate e allo Security Group dei task ECS.

Rispetto a **RDS MySQL** classico si ottiene il modello Aurora senza dover dimensionare istanze fisse per un profilo di traffico variabile. Rispetto ad **Aurora provisioned**, si evita di pagare capacità sempre accesa quando il carico è intermittente — profilo tipico di siti editoriali o ambienti non costantemente saturi.

A carico costantemente elevato, ACU fissi o istanze provisioned possono risultare più prevedibili nei costi. La rotazione della master password richiede inoltre il riciclo dei task ECS per acquisire le nuove credenziali.

### Cache: ElastiCache Valkey Serverless

L’object cache usa **ElastiCache Valkey Serverless** (engine 9), Multi-AZ gestita dal servizio, con autenticazione RBAC. Host e credenziali sono iniettati nel task ECS; lato WordPress si attiva il plugin Redis Object Cache da wp-admin, senza configurare di default nulla su deploy applicativo da Docker file (wrappe leggero).

L'introduzione della cache, rispetto alla soluzione "nativa" senza plugin, riduce il carico su Aurora e i tempi di risposta delle pagine dinamiche. Rispetto a **Redis/Valkey node-based**, il modello Serverless abbassa il costo a riposo e fornisce HA senza dover accettare uno scenario single-AZ per contenere la spesa; su ElastiCache, Valkey ha inoltre un profilo di costo più favorevole di Redis OSS.

La fatturazione segue ECPU e storage (meno “flat” di un nodo `cache.t`*). L’auth IAM nativa di ElastiCache è poco praticabile con i client WordPress/Predis: si usano quindi password RBAC in Secrets Manager.

### Filesystem applicativo: EFS su `/var/www/html`

Il document root è su **EFS Multi-AZ** montato in `/var/www/html`, con encryption in transit, autenticazione IAM e access point POSIX allineato a `www-data`. Il pattern segue il volume ufficiale dell’immagine Hub: volume vuoto montato inizialmente dall’entrypoint (task ECS). WordPress è stateful: con più task, plugin e theme installati da wp-admin restano coerenti tra le istanze.

EFS è un componente fondamentale per garantire la condivisione dello stato tra più istanze (che siano EC2, trask ECS o pod EKS) e garantire all'utente finale l'utilizzo corretto di tutte le feature WordPress. Il progetto non prevede in fase di deploy applicativo di prepopolare EFS con i necessari plugin per il corretto funzionamento dell'architettura (utilizzo S3 e Elasticache) e demanda la configurazione manuale al primo accesso.

Dopo il primo seed i file core vivono su EFS: un rebuild dell’immagine non sovrascrive un volume già popolato. Si accettano latenza e operazioni tipiche di NFS, e un possibile breve overhead sulla health check ALB a cold start.

### Edge: CloudFront + WAF davanti all’ALB

L'edge pubblico è **CloudFront + WAF** (regole managed in modalità BLOCK, Shield Standard incluso, con regole WordPress standard e rate limit definito su endpoint di login); l’ALB è origin HTTP nelle subnet pubbliche. Su CloudFront restano terminazione TLS, caching di statici/media e il filtro perimetrale, senza esporre l’ALB come unico ingresso Internet. In assenza di dominio custom lo stack è subito raggiungibile su `*.cloudfront.net`.

Un **ALB internet-facing** senza CDN semplificherebbe lo stack ma perderebbe caching globale e un layer WAF consolidato at the edge. **TLS diretto sull’ALB** con dominio custom e ACM è la strada naturale in produzione enterprise; nella baseline non si introduce Route 53/ACM sull’origin finché non c’è un dominio dedicato.

Di conseguenza TLS non è end-to-end fino all’ALB. `/wp-admin` resta raggiungibile via Internet dietro WAF e autenticazione WordPress; l'introduzione di un dominio associato, così come eventuali Cloudfront functions per verifiche di sicurezza (es. header) sono state lasciate come necessarie evolutive.

### Networking egress: due NAT Gateway

L’egress dalle subnet private passa da **due NAT Gateway** (uno per AZ), così il path di uscita resta ridondato come il resto dello stack multi-AZ. Il traffico verso S3 usa un **Gateway VPC Endpoint** gratuito: media e log non attraversano i NAT e non ne aumentano il costo di trasferimento.

Un **NAT singolo** ridurrebbe il costo fisso ma introdurrebbe uno SPOF sul path di egress, in contrasto con l’obiettivo di fault tolerance multi-A della soluzione archiretturale proposta. Gli **Interface VPC Endpoint** (ECR, Secrets Manager, Logs, …) sono una buona pratica enterprise, ma aggiungono un costo orario rilevante sopra due NAT già presenti: per un singolo workload WordPress il rapporto beneficio/costo va attentamente valutato per giustificarne l’inserimento in baseline.

Il costo fisso dei due NAT resta significativo; il traffico ECS verso ECR, Secrets Manager e CloudWatch Logs attraversa i NAT e non è dunque "private".

### Secret: ownership nel modulo del servizio

Ogni secret vive nel modulo owner della risorsa che lo consuma: password Aurora in `database` (gestita da RDS), auth Valkey in `cache`, AUTH_KEY/salts WordPress in `ecs`. L’encryption at rest usa chiavi AWS-managed. L’admin CMS non è un secret Terraform: nasce dal wizard WordPress e resta nel database applicativo.

Un **modulo `secrets` centrale** con CMK dedicata avrebbe senso in una piattaforma multi-workload con governance chiavi condivisa; su un singolo stack WordPress duplicava ownership, imponeva ordinamenti artificiosi e aggiungeva cerimonia senza beneficio operativo chiaro. Collocare i secret accanto alla risorsa mantiene dipendenze lineari e ownership esplicito.

### Release applicativa: build-arg CMS + tag ECR `app`

La versione WordPress è un **build-arg** Docker (`WORDPRESS_VERSION`); il deploy punta al tag ECR mutabile `app`, già referenziato dalla task definition bootstrap. Il service ECS ignora i cambi di `task_definition` nello state (`lifecycle.ignore_changes`), così le release applicative (build/push + force-new-deployment) non vengono sovrascritte dal successivo `terraform apply`. Infrastruttura e CMS restano cicli di vita distinti.

 **Tag ECR immutabili** per build darebbero rollback più rigorosi, a fronte di un flusso di release più articolato. Tale soluzione è comunque più aderente alle best practice e consente rollback più puntuali e per questo è considerata come una potenziale evolutiva.

Il modello attuale privilegia la separazione dei cicli di vita: aggiornare WordPress richiede build e push, non un apply Terraform ne una revisione della task definition. Sovrascrivendo `app` si indebolisce il puntamento esplicito alla build precedente (il digest resta finché il lifecycle ECR non lo elimina); tag immutabili restano l’evoluzione naturale per ambienti con esigenze di rollback più stringenti, considerando il vincolo di dover, in fase di rilascio applicativo, creare nuova tas definition ECS con il puntamento corretto.

Alcune scelte migliorative o elementi che, per tempistiche implementative o trade-off sui costi, sono state al momento lasciate fuori dalla baseline, sono riportate nel capitolo [Evolutive](#8-evolutive-e-ottimizzazioni).

---

## 5. Prerequisiti

### Account AWS e permessi

- Un account AWS con privilegi sufficienti a creare e gestire, tra gli altri: VPC/networking, ECS, ECR, ALB, CloudFront, WAF, Aurora, ElastiCache, EFS, S3, IAM, Secrets Manager, CloudWatch Logs.
- Credenziali AWS configurate in locale (profilo CLI o variabili d’ambiente) per poter runnare i comandi Terraform. Verifica: `aws sts get-caller-identity` deve restituire l’account atteso.

### Software


| Componente | Versione minima                               | Note                                                                       |
| ---------- | --------------------------------------------- | -------------------------------------------------------------------------- |
| Terraform  | ≥ 1.10                                        | Richiesto per il locking nativo S3 (`use_lockfile`); provider AWS `~> 6.0` |
| AWS CLI    | 2.x                                           | Usata per backend bootstrap, login ECR e update del service ECS            |
| Docker     | Engine ≥ 20.10 (o Docker Desktop equivalente) | Build e push dell’immagine WordPress                                       |


### Configurazione di riferimento

L’ambiente Terraform di default è `dev` in regione `eu-central-1` (variabile `aws_region`). Il WebACL WAF associato a CloudFront viene creato in `us-east-1` tramite il provider alias già definito nel codice: non richiede una configurazione manuale aggiuntiva oltre alle credenziali AWS valide.

---

## 6. Come utilizzare il progetto

Questa sezione descrive il percorso operativo completo: dal provisioning dell’infrastruttura al primo accesso a WordPress.

Il ciclo di vita della **piattaforma** (Terraform) e quello dell’**applicazione** (immagine Docker + rolling ECS) sono separati. Al primo avvio: `terraform apply` completo → pubblicazione dell’immagine su ECR → `force-new-deployment` del service.

> Dopo il solo `apply`, i task ECS falliscono il pull (`CannotPullContainerError`) finché ECR non contiene immagine con il tag `app`. È il comportamento atteso in fase di bootstrap.

### 6.1 Backend Terraform (una tantum)

```bash
./terraform/scripts/init-backend.sh
```

Lo script crea un bucket S3 versionato ed encrypted (`terraform-state-<ACCOUNT_ID>-eu-central-1`). Poi:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Modifica owner, repository e sizing se necessario

terraform init \
  -backend-config="bucket=terraform-state-<ACCOUNT_ID>-eu-central-1" \
  -backend-config="region=eu-central-1"
```

Non versionare `terraform.tfvars` con dati sensibili. Lo state resta sul bucket remoto.

### 6.2 Provisioning infrastruttura

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

Output rilevanti dopo l’apply:


| Output                                  | Descrizione                                                                         |
| --------------------------------------- | ----------------------------------------------------------------------------------- |
| `cloudfront_url`                        | URL pubblico HTTPS del sito                                                         |
| `ecr_repository_url`                    | Repository di destinazione per `docker push`                                        |
| `ecs_cluster_name` / `ecs_service_name` | Identificativi per l’update del service ECS                                         |
| `alb_dns_name`                          | DNS dell’origin ALB (utile in diagnostica; l’accesso utente avviene via CloudFront) |


### 6.3 Build e push dell’immagine WordPress

```bash
# Dalla root del repository
AWS_REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="<nome-repository-da-output-ecr>"   # es. wordpress-dev-wordpress-apache
IMAGE_TAG=app
WORDPRESS_VERSION=7.0

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_URL}"

docker build \
  --build-arg "WORDPRESS_VERSION=${WORDPRESS_VERSION}" \
  -t "${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}" \
  docker/

docker push "${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}"
```

`WORDPRESS_VERSION` è solo il build-arg CMS. Il tag ECR di deploy resta `app` (mutabile).

### 6.4 Aggiornamento del service ECS

```bash
AWS_REGION=eu-central-1
CLUSTER="<ecs_cluster_name>"    # da terraform output
SERVICE="<ecs_service_name>"    # da terraform output

aws ecs update-service \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --force-new-deployment \
  --region "${AWS_REGION}"

aws ecs wait services-stable \
  --cluster "${CLUSTER}" \
  --services "${SERVICE}" \
  --region "${AWS_REGION}"
```

Il flag `--force-new-deployment` è necessario: in bootstrap il deployment circuit breaker può aver interrotto i tentativi falliti sul pull dell’immagine.

Per le release successive (cambio versione WordPress o rebuild dell’immagine): ripetere solo i passi 6.3 e 6.4. Eseguire `terraform apply` quando cambia l’infrastruttura.

> **CI/CD** — L’automazione di build/push ECR e rolling ECS (ad esempio via GitHub Actions con OIDC) è prevista come evolutiva e verrà documentata in una versione successiva di questo README. Il percorso che verrà supportato oggi è quello manuale descritto sopra. Non si prevedono pipeline DevOps per automatizzare il provisioning infrastrutturale (Terraform), per cui sono attese modifiche/ricicli molto limitati nel tempo.

### 6.5 Primo accesso a WordPress

1. Aprire nel browser l’URL restituito da `terraform output -raw cloudfront_url`.
2. Completare il wizard di installazione WordPress (crea l’utente amministratore CMS; non è gestito da Terraform e verrà salvato a db).
3. Da **wp-admin**, installare e attivare:
  - **Redis Object Cache**, quindi abilitare l’object cache  
   (host e credenziali Valkey sono già iniettati tramite `WORDPRESS_CONFIG_EXTRA` e i secret del task ECS)
  - **WP Offload Media Lite** (`amazon-s3-and-cloudfront`), quindi abilitare il plugin  
  (bucket e delivery domain CloudFront sono già predisposti nella configurazione del task)

Il contratto applicativo è l’immagine ufficiale Hub e le relative variabili d’ambiente, configurate in fase di provisioning dell'ambiente e delle risorse infrastrutturale.

### 6.6 Verifica

- Home WordPress raggiungibile in HTTPS tramite CloudFront.
- Target group ALB healthy sulla health check `GET /`.
- Log del container disponibili nel log group CloudWatch indicato dall’output `ecs_log_group_name`.
- UAT di utilizzo dell'applicativo, con verifica delle singole funzionalità

---

## 7. Costi

### Use case di riferimento

La baseline è dimensionata per un sito WordPress aziendale o editoriale con:

- disponibilità multi-AZ e path di egress da subnet private ridondato;
- traffico medio-basso con picchi occasionali (capacità Serverless su database, cache e compute layer);
- edge caching e offload dei media su CDN/S3;
- un ambiente `dev` come composition root di partenza; in contesto multi-ambiente si riusano gli stessi moduli per `staging` / `prod`.

Il dimensionamento privilegia resilienza e chiarezza architetturale rispetto alla minimizzazione assoluta della spesa.

### Macrostima dei costi running

Di seguito, allo scopo di correttamente qualificare i costi ricorrenti per manutenere e fare girare WordPress, si riportano i valori indicativi in **euro** per `eu-central-1`. Il costo effettivo dipende da ACU, ECPU, trasferimento dati e hit ratio CDN.


| Voce                                              | Stima orientativa    |
| ------------------------------------------------- | -------------------- |
| ECS Fargate (2 task base + burst Spot)            | ~€20                 |
| Aurora Serverless v2 (writer + reader, floor ACU) | ~€75–80              |
| ElastiCache Valkey Serverless                     | ~€5–10               |
| ALB                                               | ~€15–20              |
| NAT Gateway ×2                                    | ~€60                 |
| CloudFront + WAF (senza Bot Control)              | ~€10                 |
| S3 + Secrets Manager + CloudWatch + ECR + EFS     | ~€15                 |
| **Totale stimato**                                | **~€200–220 / mese** |


A traffico minimo i costi di Aurora e Valkey tendono a ridursi; NAT Gateway e ALB restano tra le componenti fisse più rilevanti del networking.

Si sottolinea come questa baseline non è la soluzione più economica per "mettere online" WordPress: per un blog personale o un sito a basso traffico esistono opzioni molto più leggere e meno costose (hosting gestito, singola istanza, stack ridotti). È invece una piattaforma enterprise-oriented: multi-AZ, edge protection, secret management, caching, scalabilità e separazione piattaforme/applicativo — scelte che hanno un costo fisso di rete e dati non confrontabile con un setup “minimal”.

### Opzioni di ottimizzazione dei costi e relative implicazioni


| Opzione                                     | Impatto economico stimato          | Implicazioni                                                                                                              |
| ------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| NAT Gateway singolo                         | circa −€25–30 / mese               | Introduzione di uno SPOF sul path di egress di un’AZ                                                                      |
| Solo writer Aurora (senza reader)           | Riduzione del consumo ACU          | Failover e capacità di read offload più limitati                                                                          |
| Limiti ACU / ECPU più bassi                 | Tetto di spesa più stringente      | Minore headroom sotto carico                                                                                              |
| Price class CloudFront più restrittiva      | Riduzione dei PoP utilizzati       | Possibile aumento di latenza fuori dalle aree coperte - già ristretta attualmente (nelle tfvars di esempio) a Europe + US |
| Omissione di Valkey in ambienti non critici | Eliminazione del costo cache       | Maggior carico su Aurora e tempi di risposta peggiori                                                                     |
| Peso Fargate Spot più elevato               | Riduzione del costo compute        | Minora resilienza applicativa                                                                                             |
| VPC Interface Endpoints (evolutiva)         | Meno traffico NAT verso le API AWS | Costo fisso orario aggiuntivo; da valutare sul profilo di traffico                                                        |


Ad ogni modo, in contesti enterprise di produzione è generalmente preferibile rafforzare osservabilità, backup, disaster recovery, gestione chiavi e adottare un dominio, andando ad inficiare ulteriormente sui costi running.

---

## 8. Evolutive e ottimizzazioni

La baseline copre i requisiti principali di sicurezza, disponibilità e scalabilità. Restano miglioramenti naturali per un contesto enterprise o per affinare costi e operatività, non attualmente implementate per ragioni di tempistiche o costi operativi.

**Operatività e qualità del release**

- Pipeline CI/CD applicativa (build → ECR → rolling ECS), con auth OIDC e senza `terraform apply` automatico
- Tag ECR immutabili + tagging per-build (oggi il deploy usa il tag mutabile `app`) con revisione della ECR image di riferimento sulla task definition (nuova)
- Enhanced scanning immagini (Inspector) - ora base scanning

**Identità e rete pubblica**

- Route 53 + dominio custom + certificato ACM (TLS end-to-end anche sull’origin, se richiesto)
- Sottodominio dedicato ai media (es. `media.example.com`) sulla stessa distribuzione CloudFront, da usare come delivery domain di WP Offload Media: come consigliato da linee guida plugin
- Security headers CloudFront e verifiche at the edge (es. Cloudfront function per verifica login)

**Sicurezza e compliance**

- WAF Bot Control, solo se necessario visto il conseguente aumento dei costi
- AWS Backup e implementazione strategia/infrastruttura di DR
- VPC Interface Endpoints (ECR, Secrets Manager, Logs, …) se il profilo di carico verso le risorse AWS lo giustifica

**Dati e performance**

- Replica di lettura dedicata / tuning ACU
- Throughput EFS provisioned se il document root diventa bottleneck

**Osservabilità avanzata (non inclusa in questa baseline)**

- Allarmi CloudWatch (ECS, ALB 5xx, Aurora ACU, Valkey, CloudFront, WAF) + SNS
- Logging di ALB e CloudFront (verso AWS CLoudwatch, considerando costi di trasferimento più elevati, o verso un bucket S3 dedicato)
- Dashboard di sintesi e correlazione log/metriche

---

# English

## Table of contents

1. [Context](#1-context)
2. [Architecture](#2-architecture)
3. [Stack](#3-stack-1)
4. [Key decisions and trade-offs](#4-key-decisions-and-trade-offs)
5. [Prerequisites](#5-prerequisites)
6. [How to use this project](#6-how-to-use-this-project)
7. [Costs](#7-costs)
8. [Roadmap and further optimisation](#8-roadmap-and-further-optimisation)

---

## 1. Context

This repository delivers a full AWS footprint for WordPress that is **secure**, **fast**, **fault-tolerant**, and **scalable**, entirely managed with **Terraform**.

The goal is to provide a baseline suitable for an editorial or corporate workload: protected edge (CloudFront + WAF), containerised compute on ECS Fargate, Aurora MySQL for data, Valkey for object cache, shared filesystem on EFS, media on S3. The CMS version is a build-time parameter; infrastructure stays independent of the application release cycle.

The coded environment is `dev` (region `eu-central-1`). Modules are structured so additional environments can be composed without rewriting the stack.

---

## 2. Architecture

### Overview

The solution is a multi-AZ WordPress platform on AWS, organised in layers and provisioned with Terraform. Public access goes exclusively through a CloudFront Content Delivery Network (CDN) edge; application compute stays in private subnets; persistent data stores (database and cache) live in isolated subnets with no Internet route.

**Request path**

1. The client reaches CloudFront over HTTPS (default `*.cloudfront.net`). The WAF WebACL (BLOCK mode) filters traffic before it reaches the origin.
2. Dynamic requests (HTML/PHP and non-cacheable paths) are forwarded to the Application Load Balancer in public subnets. The origin is HTTP on port 80: without a custom domain, no ACM certificate is issued on the ALB; TLS termination stays on CloudFront.
3. The ALB distributes load across ECS Fargate tasks (Apache + PHP 8.3) in private subnets, across two Availability Zones, with a `GET /` health check.
4. Each task mounts the same EFS filesystem at `/var/www/html` (shared document root), so plugins and themes installed from wp-admin remain consistent across instances (WordPress is a stateful application).
5. The runtime talks to Aurora MySQL (writer + reader) and Valkey Serverless for object cache (once the Redis Object Cache plugin is enabled), both reachable only from the ECS consumer Security Groups.
6. Once WP Offload Media is enabled, media live in a private S3 bucket and are served from the same CloudFront distribution via Origin Access Control. VPC traffic to S3 uses a Gateway VPC Endpoint (it does not traverse the NAT Gateways).

**Platform / application separation**

Terraform builds and wires the platform (network, ALB, ECS, Aurora, Valkey, EFS, S3, ECR, CloudFront/WAF, wiring secrets). The WordPress image is a separate artefact: Docker build with a parametrisable `WORDPRESS_VERSION`, push to ECR under the deploy tag `app` (fixed in the current design so the task definition does not need to change on application deploy), then an ECS service rolling update.

The CMS administrator is created by the WordPress wizard on first access, not by Terraform setup.

**Network layout**

The VPC (default `10.0.0.0/16`) is split into three tiers across two AZs: public (ALB, NAT), private (ECS, EFS mount targets), and isolated (Aurora, Valkey). Egress from private subnets uses two NAT Gateways. Terraform modules stay independent: each resource owns its Security Group; cross-module rules and the EFS filesystem IAM policy are composed in the `environments/dev` root to avoid cyclic dependencies.

Infrastructure architecture:

![WordPress on AWS architecture diagram](./docs/WP_AWS_architecture.png)

### Tiered networking and security


| Tier     | Role             | Main controls                                                              |
| -------- | ---------------- | -------------------------------------------------------------------------- |
| Edge     | CloudFront + WAF | TLS termination, static/media caching, WAF for perimeter security          |
| Public   | ALB              | Only the expected edge → origin path, with a dedicated SG                  |
| Private  | ECS Fargate, EFS | No direct Internet ingress; egress via NAT Gateway (e.g. plugin downloads) |
| Isolated | Aurora, Valkey   | No Internet route; ingress only from consumer SGs (ECS)                    |


Each Security Group is owned by its resource module (`alb`, `ecs`, `database`, `cache`, `efs`). Cross-module rules and the EFS filesystem policy (ECS task role) are composed in `terraform/environments/dev` (`sg_rules_composer.tf`, `efs_policy.tf`).

### Compute and scaling

- **Task**: single `wordpress-apache` container (official Docker Hub pattern: [https://hub.docker.com/_/wordpress](https://hub.docker.com/_/wordpress)), tunable CPU/memory (default 512 / 1024).
- **Service**: minimum 2 tasks (one per AZ) for high availability; Fargate Standard and Fargate Spot capacity providers for scaling, reducing cost in environments below production.
- **Autoscaling**: target tracking on CPU and ALB request count.
- **ALB health check**: `GET /` (matcher `200` / `301` / `302`); the Hub image does not expose a dedicated lightweight `/healthz` endpoint.

### Data and secrets

- **Aurora**: master password managed by RDS in Secrets Manager (`manage_master_user_password`), with rotation.
- **Valkey**: RBAC auth; credentials in Secrets Manager inside the `cache` module.
- **WordPress**: AUTH_KEY and salts required by the Docker image, centralised in Secrets Manager (`ecs` module); the CMS admin user is not managed by Terraform.
- **Encryption at rest**: AWS-managed keys in the baseline.

### Repository layout

```
.
├── docker/                          # Dockerfile (official WP Apache image + version build-arg)
├── docs/                            # Architecture diagram
├── terraform/
│   ├── modules/
│   │   ├── networking/              # VPC, subnets, NAT ×2, S3 Gateway Endpoint
│   │   ├── efs/                     # Shared filesystem + access point
│   │   ├── storage/                 # Media and logs buckets
│   │   ├── database/                # Aurora Serverless v2 + SG + master secret
│   │   ├── cache/                   # Valkey Serverless + RBAC/Secrets + SG
│   │   ├── ecr/                     # Image repository
│   │   ├── alb/                     # Load balancer + target group + SG
│   │   ├── cdn/                     # CloudFront + WAF (+ media bucket OAC policy)
│   │   └── ecs/                     # Cluster, task, service, IAM, autoscaling, salts
│   ├── environments/dev/            # Composition root (module wiring + SG + EFS policy)
│   └── scripts/init-backend.sh      # One-time S3 bucket for Terraform state
└── README.md
```

Naming: `{project}-{environment}-{resource}` (e.g. `wordpress-dev-vpc`). Common tags: `Project`, `Environment`, `ManagedBy=Terraform`, `Repository`, `Owner`.

---

## 3. Stack


| Layer      | Technology / service                                     | Notes                                                                     |
| ---------- | -------------------------------------------------------- | ------------------------------------------------------------------------- |
| CMS        | WordPress (`WORDPRESS_VERSION` build-arg, default `7.0`) | Parametrisable CMS version; ECR deploy tag currently fixed                |
| Runtime    | Apache + mod_php (PHP 8.3)                               | Official Docker Hub image, thin wrapper to parametrise the version        |
| Compute    | ECS Fargate                                              | Single-container task, 2 AZs                                              |
| Database   | Aurora MySQL 8.0 Serverless v2                           | Writer + reader Multi-AZ                                                  |
| Cache      | ElastiCache Valkey Serverless                            | Object cache (plugin installed from wp-admin on first application access) |
| CDN / edge | CloudFront + WAF                                         | TLS on `*.cloudfront.net`                                                 |
| Media      | Private S3 + CloudFront OAC                              | WP Offload Media plugin from wp-admin on first application access         |
| App FS     | Multi-AZ EFS at `/var/www/html`                          | Shared plugins/themes across tasks                                        |
| Registry   | Amazon ECR                                               | Mutable deploy tag `app`                                                  |
| IaC        | Terraform ≥ 1.10, AWS provider ~> 6.0                    | S3 backend + `use_lockfile`                                               |


---

## 4. Key decisions and trade-offs

The notes below summarise the rationale behind the main choices: the adopted solution, how it compares with the most relevant alternatives, and any accepted trade-offs.

### Compute: ECS Fargate

Application compute runs on **ECS Fargate** (serverless), with at least two tasks across Availability Zones and capacity providers that combine Fargate Standard (stable base) and Fargate Spot (cost-aware peak scaling). The service uses autoscaling on CPU and ALB request count. The design stays compatible with the official WordPress Docker image with Apache, without requiring a custom runtime.

Compared with an **EC2** Autoscale fleet and AMIs to manage, Fargate removes OS patching and host capacity planning: for a standard containerised CMS the operational gain is substantial. **EKS** would remain a valid option with many services and an established Kubernetes ecosystem; for a single WordPress workload it would introduce a control plane and complexity that are not justified.

The accepted trade-off is less control over kernel and host, plus typical Fargate constraints (fixed CPU/memory steps) in capacity planning.

### Runtime in the task: Apache + mod_php in one container

The task runs a single container based on the official `wordpress:*-php8.3-apache` image, wired through `WORDPRESS_*` variables (database, public URL, salts, Valkey/S3 targets). This is the Docker Hub–supported pattern and can run as a single self-contained (monolithic) task.

Alternatives such as **nginx + php-fpm** in a multi-container task or a custom reverse proxy would offer more tuning flexibility, at the cost of more operational surface and a less Hub-aligned application contract. Performance and scale are delegated to CloudFront, Valkey, and ECS autoscaling rather than to complexity inside the task.

The trade-off is the lack of a fine-grained split between web server and PHP within the task; advanced nginx/php-fpm tuning stays out of scope.

### Database: Aurora MySQL Serverless v2

Data persists on **Aurora MySQL 8.0 Serverless v2** with a Multi-AZ writer and reader. This keeps Aurora’s distributed storage, fast failover, and continuous backup, with capacity (ACUs) that scales with real load. The master password is managed by RDS in Secrets Manager, with rotation; access stays confined to isolated subnets and the ECS task Security Group.

Compared with classic **RDS MySQL**, this keeps the Aurora model without sizing fixed instances for a variable traffic profile. Compared with **provisioned Aurora**, it avoids paying always-on capacity when load is intermittent — a typical profile for editorial sites or environments that are not constantly saturated.

Under sustained high load, fixed ACUs or provisioned instances can be more predictable on cost. Master-password rotation also requires ECS tasks to recycle to pick up new credentials.

### Cache: ElastiCache Valkey Serverless

Object cache uses **ElastiCache Valkey Serverless** (engine 9), with service-managed Multi-AZ and RBAC authentication. Host and credentials are injected into the ECS task; on the WordPress side, Redis Object Cache is enabled from wp-admin, with no default configuration required on application deploy from the Dockerfile (lightweight wrapper).

Introducing the cache, compared with a “native” solution without the plugin, reduces Aurora load and dynamic page response times. Compared with **node-based Redis/Valkey**, Serverless lowers idle cost and provides HA without forcing a single-AZ compromise to contain spend; on ElastiCache, Valkey also has a more favourable cost profile than Redis OSS.

Billing follows ECPU and storage (less “flat” than a `cache.t*` node). Native ElastiCache IAM auth is impractical with WordPress/Predis clients, so RBAC passwords in Secrets Manager are used.

### Application filesystem: EFS at `/var/www/html`

The document root lives on **Multi-AZ EFS** mounted at `/var/www/html`, with encryption in transit, IAM authentication, and a POSIX access point aligned to `www-data`. The pattern follows the official Hub image volume: an empty volume is initially mounted by the entrypoint (ECS task). WordPress is stateful: with multiple tasks, plugins and themes installed from wp-admin stay consistent across instances.

EFS is a fundamental component to share state across multiple instances (whether EC2, ECS tasks, or EKS pods) and to let end users correctly use all WordPress features. The project does not pre-populate EFS at application deploy time with the plugins required for the architecture to work correctly (S3 and ElastiCache usage) and leaves that manual configuration to first access.

After the first seed, core files live on EFS: an image rebuild does not overwrite an already-populated volume. NFS latency and operational characteristics are accepted, as is a possible brief overhead on the ALB health check at cold start.

### Edge: CloudFront + WAF in front of the ALB

The public edge is **CloudFront + WAF** (managed rules in BLOCK mode, Shield Standard included, with standard WordPress rules and a defined rate limit on login endpoints); the ALB is an HTTP origin in public subnets. CloudFront owns TLS termination, static/media caching, and perimeter filtering, without exposing the ALB as the sole Internet entrypoint. Without a custom domain, the stack is immediately reachable on `*.cloudfront.net`.

An **internet-facing ALB** without a CDN would simplify the stack but lose global caching and a consolidated WAF layer at the edge. **TLS directly on the ALB** with a custom domain and ACM is the natural path in enterprise production; in the baseline, Route 53/ACM on the origin is not introduced until a dedicated domain exists.

As a result, TLS is not end-to-end to the ALB. `/wp-admin` remains Internet-reachable behind WAF and WordPress authentication; associating a custom domain, as well as CloudFront functions for security checks (e.g. headers), are left as necessary roadmap items.

### Egress networking: two NAT Gateways

Egress from private subnets uses **two NAT Gateways** (one per AZ), so the outbound path stays redundant like the rest of the multi-AZ stack. Traffic to S3 uses a free **Gateway VPC Endpoint**: media and logs do not traverse the NAT Gateways and do not increase their data-transfer cost.

A **single NAT** would reduce fixed cost but introduce an SPOF on the egress path, conflicting with the multi-AZ fault-tolerance goal of the proposed architecture. **Interface VPC Endpoints** (ECR, Secrets Manager, Logs, …) are sound enterprise practice, but they add meaningful hourly cost on top of two NAT Gateways already present: for a single WordPress workload the benefit/cost ratio must be carefully assessed before including them in the baseline.

The fixed cost of two NAT Gateways remains significant; ECS traffic to ECR, Secrets Manager, and CloudWatch Logs traverses the NAT Gateways and is therefore not “private”.

### Secrets: ownership in the service module

Each secret lives in the owning module of the resource that consumes it: Aurora password in `database` (RDS-managed), Valkey auth in `cache`, WordPress AUTH_KEY/salts in `ecs`. Encryption at rest uses AWS-managed keys. The CMS admin is not a Terraform secret: it is created by the WordPress wizard and stays in the application database.

A central **`secrets` module** with a dedicated CMK would make sense on a multi-workload platform with shared key governance; on a single WordPress stack it duplicated ownership, forced artificial ordering, and added ceremony without a clear operational benefit. Keeping secrets next to the resource preserves linear dependencies and explicit ownership.

### Application release: build-arg CMS + ECR tag `app`

The WordPress version is a Docker **build-arg** (`WORDPRESS_VERSION`); deploy points at the mutable ECR tag `app`, already referenced by the bootstrap task definition. The ECS service ignores `task_definition` changes in state (`lifecycle.ignore_changes`), so application releases (build/push + force-new-deployment) are not overwritten by a later `terraform apply`. Infrastructure and CMS remain separate lifecycles.

**Immutable ECR tags** per build would give stricter rollback, at the cost of a more elaborate release flow. That approach is nonetheless closer to best practice and enables more precise rollback, and is therefore considered a potential roadmap item.

The current model favours separated lifecycles: updating WordPress requires build and push, not a Terraform apply or a task-definition revision. Overwriting `app` weakens an explicit pointer to the previous build (the digest remains until ECR lifecycle expires it); immutable tags remain the natural evolution for environments with stricter rollback requirements, bearing in mind that application release would then need a new ECS task definition pointing at the correct image.

Some improvements or items left out of the baseline for delivery timelines or cost trade-offs are listed under [Roadmap](#8-roadmap-and-further-optimisation).

---

## 5. Prerequisites

### AWS account and permissions

- An AWS account with sufficient privileges to create and manage, among others: VPC/networking, ECS, ECR, ALB, CloudFront, WAF, Aurora, ElastiCache, EFS, S3, IAM, Secrets Manager, and CloudWatch Logs.
- Local AWS credentials configured (CLI profile or environment variables) so Terraform commands can run. Check: `aws sts get-caller-identity` must return the expected account.

### Software


| Component | Minimum version                               | Notes                                                                  |
| --------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| Terraform | ≥ 1.10                                        | Required for native S3 locking (`use_lockfile`); AWS provider `~> 6.0` |
| AWS CLI   | 2.x                                           | Used for backend bootstrap, ECR login, and ECS service updates         |
| Docker    | Engine ≥ 20.10 (or equivalent Docker Desktop) | Build and push of the WordPress image                                  |


### Reference configuration

The default Terraform environment is `dev` in region `eu-central-1` (`aws_region` variable). The CloudFront-associated WAF WebACL is created in `us-east-1` via the provider alias already defined in code; no extra manual setup is required beyond valid AWS credentials.

---

## 6. How to use this project

This section is the end-to-end operational guide: from provisioning infrastructure to the first WordPress login.

**Platform** (Terraform) and **application** (Docker image + ECS rolling update) have separate lifecycles. First boot: full `terraform apply` → publish the image to ECR → `force-new-deployment` of the service.

> After `apply` alone, ECS tasks fail to pull (`CannotPullContainerError`) until ECR contains an image with the `app` tag. This is expected during bootstrap.

### 6.1 Terraform backend (one-time)

```bash
./terraform/scripts/init-backend.sh
```

Creates a versioned, encrypted S3 bucket (`terraform-state-<ACCOUNT_ID>-eu-central-1`). Then:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Adjust owner, repository, and sizing as needed

terraform init \
  -backend-config="bucket=terraform-state-<ACCOUNT_ID>-eu-central-1" \
  -backend-config="region=eu-central-1"
```

Do not commit sensitive `terraform.tfvars`. State stays in the remote bucket.

### 6.2 Provision infrastructure

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

Relevant outputs after apply:


| Output                                  | Description                                                                |
| --------------------------------------- | -------------------------------------------------------------------------- |
| `cloudfront_url`                        | Public HTTPS site URL                                                      |
| `ecr_repository_url`                    | Target repository for `docker push`                                        |
| `ecs_cluster_name` / `ecs_service_name` | Identifiers for the ECS service update                                     |
| `alb_dns_name`                          | ALB origin DNS (useful for diagnostics; end-user access is via CloudFront) |


### 6.3 Build and push the WordPress image

```bash
# From the repository root
AWS_REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="<repository-name-from-ecr-output>"   # e.g. wordpress-dev-wordpress-apache
IMAGE_TAG=app
WORDPRESS_VERSION=7.0

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_URL}"

docker build \
  --build-arg "WORDPRESS_VERSION=${WORDPRESS_VERSION}" \
  -t "${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}" \
  docker/

docker push "${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}"
```

`WORDPRESS_VERSION` is the CMS build-arg only. The ECR deploy tag remains mutable `app`.

### 6.4 Update the ECS service

```bash
AWS_REGION=eu-central-1
CLUSTER="<ecs_cluster_name>"    # from terraform output
SERVICE="<ecs_service_name>"    # from terraform output

aws ecs update-service \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --force-new-deployment \
  --region "${AWS_REGION}"

aws ecs wait services-stable \
  --cluster "${CLUSTER}" \
  --services "${SERVICE}" \
  --region "${AWS_REGION}"
```

`--force-new-deployment` is required: during bootstrap the deployment circuit breaker may have stopped failed image-pull attempts.

For later releases (WordPress version change or image rebuild): repeat only steps 6.3 and 6.4. Run `terraform apply` when infrastructure changes.

> **CI/CD** — Automation of ECR build/push and ECS rolling updates (for example via GitHub Actions with OIDC) is planned as a roadmap item and will be documented in a later revision of this README. The path supported today is the manual procedure above. No DevOps pipeline is planned to automate infrastructure provisioning (Terraform), which is expected to change or recycle only rarely over time.

### 6.5 First WordPress access

1. Open the URL from `terraform output -raw cloudfront_url` in a browser.
2. Complete the WordPress installation wizard (creates the CMS administrator; not managed by Terraform and stored in the database).
3. From **wp-admin**, install and activate:
  - **Redis Object Cache**, then enable object cache  
   (Valkey host and credentials are already injected via `WORDPRESS_CONFIG_EXTRA` and the ECS task secrets)
  - **WP Offload Media Lite** (`amazon-s3-and-cloudfront`), then enable the plugin  
  (bucket and CloudFront delivery domain are already set in the task configuration)

The application contract is the official Hub image and its environment variables, configured when the environment and infrastructure resources are provisioned.

### 6.6 Verification

- WordPress home reachable over HTTPS via CloudFront.
- ALB target group healthy on the `GET /` health check.
- Container logs available in the CloudWatch log group from output `ecs_log_group_name`.
- Application UAT, verifying individual features.

---

## 7. Costs

### Reference use case

Sizing targets a corporate or editorial WordPress site with:

- multi-AZ availability and redundant egress from private subnets;
- low-to-medium traffic with occasional spikes (Serverless capacity on database, cache, and compute);
- edge caching and media offload to CDN/S3;
- a `dev` environment as the starting composition root; in multi-environment setups the same modules are reused for `staging` / `prod`.

The sizing favours resilience and architectural clarity over absolute minimum spend.

### High-level running cost estimate

To qualify the recurring cost of running and maintaining WordPress, indicative figures in **euros** for `eu-central-1` are listed below. Actual cost depends on ACU, ECPU, data transfer, and CDN hit ratio.


| Item                                              | Indicative estimate   |
| ------------------------------------------------- | --------------------- |
| ECS Fargate (2 baseline tasks + Spot burst)       | ~€20                  |
| Aurora Serverless v2 (writer + reader, floor ACU) | ~€75–80               |
| ElastiCache Valkey Serverless                     | ~€5–10                |
| ALB                                               | ~€15–20               |
| NAT Gateway ×2                                    | ~€60                  |
| CloudFront + WAF (no Bot Control)                 | ~€10                  |
| S3 + Secrets Manager + CloudWatch + ECR + EFS     | ~€15                  |
| **Estimated total**                               | **~€200–220 / month** |


Under minimal traffic, Aurora and Valkey costs tend to decrease; NAT Gateways and the ALB remain among the more significant fixed networking components.

It should be stressed that this baseline is **not** the cheapest way to put WordPress online: for a personal blog or a low-traffic site there are much lighter and less expensive options (managed hosting, a single instance, reduced stacks). It is instead an enterprise-oriented platform: multi-AZ, edge protection, secret management, caching, scalability, and platform/application separation — choices that carry a fixed networking and data cost not comparable with a “minimal” setup.

### Cost optimisation options and implications


| Option                                   | Estimated cost impact            | Implications                                                                                                                         |
| ---------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Single NAT Gateway                       | about −€25–30 / month            | Introduces an SPOF on the egress path of one AZ                                                                                      |
| Aurora writer only (no reader)           | Lower ACU consumption            | More limited failover and read offload capacity                                                                                      |
| Lower ACU / ECPU caps                    | Tighter spend ceiling            | Less headroom under load                                                                                                             |
| Narrower CloudFront price class          | Fewer PoPs in use                | Possible higher latency outside covered areas — already restricted in the example tfvars to Europe + US                              |
| Omit Valkey in non-critical environments | Removes cache cost               | Higher Aurora load and slower response times                                                                                         |
| Higher Fargate Spot weight               | Lower compute cost               | Lower application resilience                                                                                                         |
| VPC Interface Endpoints (roadmap)        | Less NAT traffic to AWS APIs     | Additional hourly fixed cost; evaluate against traffic profile                                                                       |


In any case, in enterprise production it is generally preferable to strengthen observability, backup, disaster recovery, key management, and adopt a custom domain — which further increases running costs.

---

## 8. Roadmap and further optimisation

The baseline covers the main security, availability, and scalability requirements. Natural next steps remain for an enterprise context or to refine cost and operations; they are not implemented yet for delivery timelines or operating-cost reasons.

**Release quality and operations**

- Application CI/CD (build → ECR → ECS rolling), OIDC auth, no automatic `terraform apply`
- Immutable ECR tags + per-build tagging (today deploy uses mutable `app`), with a new task-definition revision pointing at the new ECR image
- Enhanced image scanning (Inspector) — basic scanning today

**Public identity and network**

- Route 53 + custom domain + ACM (end-to-end TLS to the origin if required)
- Dedicated media subdomain (e.g. `media.example.com`) on the same CloudFront distribution, used as WP Offload Media’s delivery domain, as recommended by the plugin guidelines
- CloudFront security headers and edge checks (e.g. CloudFront function for login verification)

**Security and compliance**

- WAF Bot Control, only if needed given the resulting cost increase
- AWS Backup and a DR strategy/infrastructure
- VPC Interface Endpoints (ECR, Secrets Manager, Logs, …) if the load profile toward AWS services justifies them

**Data and performance**

- Dedicated read replica / ACU tuning
- Provisioned EFS throughput if the document root becomes a bottleneck

**Advanced observability (not in this baseline)**

- CloudWatch alarms (ECS, ALB 5xx, Aurora ACU, Valkey, CloudFront, WAF) + SNS
- ALB and CloudFront logging (to CloudWatch, with higher data-transfer cost, or to a dedicated S3 bucket)
- Summary dashboards and log/metric correlation
