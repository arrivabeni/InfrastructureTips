echo -e "\e[1;33m
===========================================================================================================
Preparando ambiente
===========================================================================================================\e[0m"
echo -e "\e[1;33mAtualiza pacotes no sistema...\e[0m"
yum update -y

echo -e "\e[1;33mInstala e configura AWS CLI...\e[0m"
yum install -y aws-cli

echo -e "\e[1;33mInstala interpretador JSON - JQ JSON Client...\e[0m"
yum install -y jq

echo -e "\e[1;33m
===========================================================================================================
Cria script para auto registro DNS
===========================================================================================================\e[0m"
cat > auto-register-dns.sh << EOScript
#!/bin/bash
echo -e "\e[1;33m
===========================================================================================================
Configurando auto registro DNS
===========================================================================================================\e[0m"
echo -e "\e[1;33mUsuário logado:\e[0m"
whoami

echo -e "\e[1;33mObtém no user data da instância as variáveis...\e[0m"
export DNS=\$(curl 'http://instance-data/latest/user-data')
export AWS_ACCESS_KEY_ID=\$(curl 'http://instance-data/latest/user-data' | jq -r '.i')
export AWS_SECRET_ACCESS_KEY=\$(curl 'http://instance-data/latest/user-data' | jq -r '.k')
export AWS_DEFAULT_REGION=\$(curl 'http://instance-data/latest/user-data' | jq -r '.r')

echo -e "\e[1;33mObtém o IP público da instância...\e[0m"
IPV4=\$(curl http://instance-data/latest/meta-data/public-ipv4)
echo \$IPV4

echo -e "\e[1;33mRegistra DNS no Route53...\e[0m"

for k in \$(jq '.dns | keys | .[]' <<< "\$DNS"); do
	value=\$(jq -r ".dns[\$k]" <<< "\$DNS");
	name=\$(jq -r ".name" <<< "\$value")
	suffix=\$(jq -r ".suffix" <<< "\$value")
	zone=\$(jq -r ".zone" <<< "\$value")
	
    echo -e "\e[1;33mRegistrando \$name\$suffix...\e[0m"
	
    cat > auto-register-dns << EOF
{
"Comment": "EC2 Auto Registro",
"Changes": [{
"Action": "UPSERT",
"ResourceRecordSet": {
"Name": "\$name\$suffix",
"Type": "A",
"TTL": 60,
"ResourceRecords": [{
"Value": "\$IPV4"
}]}}]}
EOF

    aws route53 change-resource-record-sets --hosted-zone-id \$zone --change-batch file://auto-register-dns
    rm auto-register-dns

done

echo -e "\e[1;33mProcesso finalizado!\e[0m"
EOScript

echo -e "\e[1;33mConfigura script para execução no Startup...\e[0m"
mkdir /etc/route53
mv auto-register-dns.sh /etc/route53/auto-register-dns.sh
chmod +x /etc/route53/auto-register-dns.sh

cp /etc/rc.d/rc.local /etc/rc.d/rc.local.bkp
cp /etc/rc.d/rc.local rc.local

echo "/etc/route53/auto-register-dns.sh" >> rc.local

mv rc.local /etc/rc.d/rc.local

chmod u+x /etc/rc.d/rc.local
systemctl start rc-local
systemctl enable rc-local

echo -e "\e[1;33mProcesso finalizado!\e[0m"