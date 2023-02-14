# PS Cloud - configure OpenStack by Terraform and Ansible / PS Cloud - настройка OpenStack с помощью Terraform and Ansible

## Описание задания

С помощью терраформа нужно поднять 5 серверов и настроить их.

На HAproxy настроить балансировку, чтоб при обращении на статический адрес в браузере открывался сайт с одного из 3-х серверов с приветствием Welcome to `hostname`
при обновление страницы сайт должен открыться с другого сервера.

Пример:
открываем сайт по статическому  адресу, открывается страница с сервера VM1 с инфой Welcome to VM1, обновляем страницу инфа должна взяться с сервера VM2 и инфа Welcome to VM2 и так далее.

что нужно сделать:

1.Terraform

- Создать 5 VM (ОС centos  (4 VM пустые,1 VM control с нее будет запускаться роли ansible))
- на VM с HAproxy повесить floating ip
- На VM control поставить нужные пакеты
- фиксируемы локальные (серые) ip адреса
- запуск ansible role

2.Ansible

- настроить 1 Haproxy и 3 Apache
- на Apache  /opt/html/index.html со строчкой "Welcome to `hostname`"
- отключать SElinux нельзя
- role ansible должны лежать в s3

## Вариант решения задач

### Terraform для оркестрации Openstack в PS Cloud

Требование Terraform должен быть установлен

Пример использования

```bash
# Клонируем репозиторий к себе на компьютер

git clone <URL>

cd ps-test/terraform

# создаем файл ps.tfvars
# пример файл ниже в секции conf
```

```conf
# OpenStack private vars
openstack_user_name = ""
openstack_tenant_name = ""
openstack_password = ""
openstack_auth_url = "https://auth.pscloud.io/v3/"
openstack_region = "kz-ala-1"
openstack_public_key = ""
openstack_image_id = "c18b2889-b89f-4dba-b2f5-384c2d87ec2e" # Centos 7.9
openstack_apache_instance_count = 3
openstack_apache_instance_instance_name = "apache-test-vm" # prefix of Apache instance hostname
openstack_vmcontrol_instance_count = 1
openstack_vmcontrol_instance_instance_name = "vm-control-test-vm" # prefix of Apache instance hostname
openstack_haproxy_instance_count = 1
openstack_haproxy_instance_instance_name = "haproxy-test-vm"
openstack_ansible_role_url = "https://ansible-test.archive.pscloud.io/ansible.tar.gz" # URL с ansible в S3
openstack_instance_password = "" # password of a instance
```

```bash
# Проверяем что все корреткно
terraform plan --var-file="ps.tfvars"

# Применяем наш terraform
terraform apply --var-file="ps.tfvars"
```

### Проверка работы

Если все прошло корректно, то в конце будет информация о внешм IP

Если перйти по нему, то откроется страничка html с информацией об IP сервера.

Если перегрузить страницу, то IP будет меняться

Проверка в цикле старницы

```bash
for id in {1..10}; do curl http://<IP> ; done
```
