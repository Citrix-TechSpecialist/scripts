#!/usr/bin/env bash
#
# Pre-Req : sudo apt-get -y install openssh 
#
# Minimum Requirement
# USAGE : ./<Script-name>.sh <subdomain> <domain> <path-to-save-files>
# EXAMPLE : ./cert-gen.sh webgoat citrix.lab ./ssl-certs 4096 365
#
# Optional Additiona Parameters 
# USAGE : ./<Script-name>.sh <subdomain> <domain> <path-to-save-files> <key-length> <days-valid>
# EXAMPLE : ./cert-gen.sh webgoat citrix.lab ./ssl-certs 4096 365
#
# Add the fqdn.domain.name.crt and fqdn.domain.name.key to the NetScaler ADC in the following directory: /nsconfig/ssl 
#
# Add the certkey to the ADC with the command : "add certkey FQDN-cert-name -cert fqdn.domain.name.crt -key fqdn.domain.name.crt"
# Bind the cert to the vserver : "bind certkey vserver-name FQDNS-cert-name"

FQDN=$1.$2
DOMAIN=$2
CA="CA.$DOMAIN"
KEY_SIZE=${4:-2048} 
DAYS=${5:-1024} 

# Create our SSL directory
# in case it doesn't exist
SSL_DIR=$3$DOMAIN
echo $SSL_DIR
mkdir -p $SSL_DIR

# A blank passphrase
PASSPHRASE=""

# Set our CSR variables
SUBJ_ROOT="
C=US
ST=WA
O=Readiness
localityName=Seattle
commonName=$CA
organizationalUnitName=TechSpec
emailAddress=ARTS@citrix.net
"

SUBJ_FQDN="
C=US
ST=WA
O=Readiness
localityName=Seattle
commonName=$FQDN
organizationalUnitName=TechSpec
emailAddress=ARTS@citrix.net
"

# Generate our Root Cert, Root Key, Private Key, CSR and Certificate

#Check if you already have a root key in the directory, if you don't, create the root key and subsequent root cert
if ! [[ -f "$SSL_DIR/$CA.key" ]];

		then
		#Generate Root KEY
		openssl genrsa \
				-out "$SSL_DIR/$CA.key" $KEY_SIZE

		#Generate Root PEM
		openssl req \
				-x509 \
				-new \
				-nodes \
				-subj "$(echo -n "$SUBJ_ROOT" | tr "\n" "/")" \
				-key "$SSL_DIR/$CA.key" \
				-sha256 \
				-days 1024 \
				-out "$SSL_DIR/$CA.pem"

		#Convert PEM to CRT - Not Necessary, just extra code incase you need it.
		openssl x509 \
				-outform der \
				-in "$SSL_DIR/$CA.pem" \
				-out "$SSL_DIR/$CA.crt"
fi

#Check if you already have a root cert in the directory, if you don't, use the root key in the directory to create one
if ! [[ -f "$SSL_DIR/$CA.pem" ]];

	then
		#Generate Root PEM
		openssl req \
				-x509 \
				-new \
				-nodes \
				-subj "$(echo -n "$SUBJ_ROOT" | tr "\n" "/")" \
				-key "$SSL_DIR/$CA.key" \
				-sha256 \
				-days $DAYS \
				-out "$SSL_DIR/$CA.pem"

		#Convert PEM to CRT - Not Necessary, extra code.
		openssl x509 \
				-outform der \
				-in "$SSL_DIR/$CA.pem" \
				-out "$SSL_DIR/$CA.crt"
fi

#Generate FQDN Private Key
openssl genrsa \
		-out "$SSL_DIR/$FQDN.key" $KEY_SIZE

#Generate CSR for request
openssl req \
		-new \
		-sha256 \
		-key "$SSL_DIR/$FQDN.key" \
		-subj "$(echo -n "$SUBJ_FQDN" | tr "\n" "/")" \
		-out "$SSL_DIR/$DOMAIN.csr"

#Sign CSV to make CRT with root cert
openssl x509 \
		-req \
		-in "$SSL_DIR/$DOMAIN.csr" \
 		-CA "$SSL_DIR/$CA.pem" \
		-CAkey "$SSL_DIR/$CA.key" \
		-CAcreateserial \
		-out "$SSL_DIR/$FQDN.crt" \
		-days $DAYS \
		-sha256
echo "Here is the verification of the server certificate cross examined with root CA"
openssl verify -verbose -CAfile "$SSL_DIR/$CA.pem" "$SSL_DIR/$FQDN.crt"
echo "Here is the human readable format of the server certificate."
openssl x509 -noout -text -in "$SSL_DIR/$FQDN.crt"
