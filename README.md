# PROJECT-webserver
# Solution Architecture & High-Level Design

-------------------------------------------------------------------------------------------------
|Solution Name:     | Three tier Web Application architecture  using Apache, NodeJS and Postgres | 
|-------------------|----------------------------------------------------------------------------|
|Author             | Rajan Jha                                                                  |
-------------------------------------------------------------------------------------------------

# Table of Contents 

1.	Solution Summary
2.	Requirements
3.	Folder structure
4.	Deployment
   *	Prerequisite
   *	TF setup
5.  Kubernetes Deployment:
      * K8S cluster deployment on AWS using same VPC


# 1.Solution Summary

We will create a three-tier architecture leveraging Terraform modules. Our architecture will reside in a custom VPC.
This application is hosted on AWS and consumes below AWS resources – 

*	VPC
*	Public and Private Subnets
*	Nat and Internet Gateway
*	Security groups
*	Linux AMI's,ELB, Launch templates and ASG
*	S3
*	Postgres RDS
*	DynamoDB
*   EKS

PART -1 : 

This solution deploys this web application in us-east-1. 
The web tier will have a bastion host and NAT gateway in the public subnets. The bastion host will serve as our access point to the underlying infrastructure. The NAT Gateway will allow our private subnets to access updates from the internet.

In the application tier, we will create an internet facing load balancer to direct internet traffic to an autoscaling group in the private subnets, along with a backend autoscaling group for our backend application. We will create a script to install the apache webserver in the frontend, and a script to install Node.js in the backend.

We will have another layer of private subnets in the database tier hosting a Postgres database which will will eventually access using Node.js.

PART -2 

Deploys a K8S cluster using same VPC. Application can be deployed using CI/CD Pipelines. We can dockerise the application code and create an artifact using CI pipeline. Same artefact can be deployed using a CD pipeline. We can use kubernetes deployments files to deploy the container and create kubernetes services to connect to the application.

# 2. Requirements

|             Requirements	                                |                          Solution                                 |
------------------------------------------------------------|--------------------------------------------------------------------
|Must be deployed in AWS VPC                                | Creating AWS vpc, subnets, nat, security groups using TF          | 
|Application set up to be public facing using load balancer | Using a public facing lb, using launch template and asg           |
|Application will use a managed Postgres database           | Application server is using a postgres RDS instance               |
|Application will need an object storage bucket             | Installation scripts are kept on s3, consumed by backend instances|


# 3. Folder structure

```
.
|
terraform
├── modules                   # terraform local modules
|   ├── database              # Module for postgres databse
|   └── remote-state          # setup s3 as remote backed with dynamodb for tfstate locking
|   ├── networking            # Creates AWS networking resources
|   |-- servers               # Creates launch templates and asg for bastion, web and application instances
|   |-- lb                    # Load balancers, target group and listner
|   |-- k8s                   # EKS Cluster setup for part 2 of the assignment
|-- source                    # Installation scripts for web and application servers
...
(terraform files)             # Terraform config to deploy all the modules, s3 bucket and db secrets.
...             
└── README.md

```
* Modules

* Networking
Contains the VPC, subnets, internet gateway, route tables, NAT gateways, security groups, and database subnet group. 

we will create the public subnets using a count variable to control the number we want. We will set up the cidr_block so that the subnets can exist within the specified VPC cidr range. The public subnet route table will route to the internet gateway. We will also create the NAT gateway that will connect with our private instances.

We will create the private subnets next that will reside in the application tier and database tier. Here will will associate a private route table with the NAT Gateway.

main.tf networking file, we will make security groups (sg) to allow proper permissions for each level. The bastion sg will allow you to connect to the bastion EC2 instance. We have the load balancer sg, frontend app sg, backend app sg, and database sg. 

* servers

We will obtain the latest AMI using the AWS SSM parameter store. Next, to be able to access our Bastion host, we will need a key pair generated using TF.

Now we will create our auto scaling groups in the private subnets. We will copy the scripts to s3 bucket which will be fectched by ec2 instances to install the web and application server using user data.

* Loadbalancing
For the main.tf file here, we will create the load balancer, target group, and listener. Note that the load balancer lies in the public subnet layer.

* Database
Onto the last module. For the main.tf file here, we have a block that builds the database.

# 4. Deployment

 * # Prerequisite 

    1. Configure AWS on your local system with credetials in ~/.aws/credentials.
    2. Terraform (> v1.0.11 or higher). 

  # Terraform Setup

    # S3 as backend 

    This project used S3 as remote backend with dynamoDB for tfstate locking.
    This is a one time activity to setup the s3 bucket and dynamodb required for the backend.

    1. ``` cd modules/remote-state ``` 
    2. Run ``` terraform init ``` ```terraform plan``` ```terraform deploy``` 
    3. Fetch the s3 bucket and dynamo table name from ```output```

    # Application deployment

    * We are deploying the application with a modular approach in us-east-1 defind in main.tf. 

    Steps to deploy - 
      * Clone the repo on your local system and ```cd project-webserver/terraform```
      * setup backend.tf with earlier created backend resources.
      * setup aws providers.
      * Create variables in ```variables.tf``` and put all the values in ```terraform.tfvars```
      * Run ```terraform init``` ```terraform plan``` and ```terraform apply```. 
      * To access the web application copy the load balancer endpoint we got from our Terraform output, and place it in the search bar, we will see the message we specified in our script for the Apache webserver. 

    # DB Connection
      * Login to bastion host.
      * Copy your key to bastion and login to the application instance.
      * Make sure node is installed on the application host ``` #node --version ```
      * Install postgres ```npm install pg```
      * Edit the postgres_connection.js to connect with the database 
        ```
        var mysql = require('mysql');
        var con = mysql.createConnection({
        host: "database_endpoint from Terraform Output",
        user: "dbuser from tfvars file",
        password: "dbpassword from tfvars file"
        });
        con.connect(function(err) {
        if (err) throw err;
        console.log("Connected!");
        }); 

        ```

# 5. Kubernets deploymenet
     

|             Requirements	                                 |                        Solution                 |
-------------------------------------------------------------|--------------------------------------------------
|Kubernetes (K8s) cluster on EKS using same vpc              | Creating K8S Cluster using offical TF EKS module|
|Cluster should use a node pool with 2 CPU and 8GB or memory | Use a required t2.large ec2 instance            |

* Module
* K8S 

This module is used to deploy an EKS cluster on AWS while using the same networking components which are created by networking modules. It sits in the same vpc while using teh same subnets created by the networking module.The cluster is using a node pool created with t2.large instance with 2 CPU and 8GB of memory.