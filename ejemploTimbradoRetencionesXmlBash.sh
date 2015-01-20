#!/bin/bash
# Ejemplo de timbrado desde Bash

########### Notas ############
## Instalar el paquete curl ##
##############################

### Declaracion de Variables
DATE=`date +'%Y-%m-%dT%H:%M:00'`
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="ESI920427886"
URLTIMBRADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
GENERARTXT="false"
GENERARPDF="true"
GENERARCBB="false"
FILE_XML="XmlUTF8.xml"
XSLTFILE="utilerias/retenciones_xslt/retenciones.xslt"
KEYFILE="utilerias/certificados/20001000000200000192.key"
CERTFILE="utilerias/certificados/20001000000200000192.cer"
PEMFILE="utilerias/certificados/20001000000200000192.key.pem"
PASS="12345678a"
TMP="tmp.txt"
retencionesxml="retenciones.xml"
retencionespdf="retenciones.pdf"
FILE_RESPONSE="soap_response.xml"
code=""
###

## Crear Layout
FILE=$(cat<<EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<retenciones:Retenciones xmlns:retenciones="http://www.sat.gob.mx/esquemas/retencionpago/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation=" http://www.sat.gob.mx/esquemas/retencionpago/1 http://www.sat.gob.mx/esquemas/retencionpago/1/retencionpagov1.xsd" Version="1.0" FolioInt="RetA" Sello="" NumCert="" Cert="" FechaExp="$DATE-06:00" CveRetenc="05">
	    <retenciones:Emisor RFCEmisor="ESI920427886" NomDenRazSocE="Empresa retenedora ejemplo"/>
	    <retenciones:Receptor Nacionalidad="Nacional">
	        <retenciones:Nacional RFCRecep="XAXX010101000" NomDenRazSocR="Publico en General"/>
	    </retenciones:Receptor>
	    <retenciones:Periodo MesIni="12" MesFin="12" Ejerc="2014"/>
	    <retenciones:Totales montoTotOperacion="33783.75" montoTotGrav="35437.50" montoTotExent="0.00" montoTotRet="7323.75">
	        <retenciones:ImpRetenidos BaseRet="35437.50" Impuesto="02" montoRet="3780.00" TipoPagoRet="Pago definitivo"/>
	        <retenciones:ImpRetenidos BaseRet="35437.50" Impuesto="01" montoRet="3543.75" TipoPagoRet="Pago provisional"/>
	    </retenciones:Totales>
	</retenciones:Retenciones>
EOF
)


echo $FILE > $FILE_XML

## Obtener contenido del certificado en base 64
certificado=`openssl enc -base64 -A -in $CERTFILE > $TMP`
certificado=`sed -e "s/\\//\\\\\\\\\//g" $TMP`

## Obtener el numero del certificado
numcert=`openssl x509 -inform DER -in $CERTFILE -noout -serial`
numcert=`echo $numcert | cut -d"=" -f 2`
t=${#numcert}
for i in `seq 1 $t`
do
    n=$((i%2))
    if [ $n -eq 0 ]
        then
        l1=`echo $numcert | cut -c $i`
        str=$str$l1
    fi
done
numcert=$str


## Agrear Informacion del Sello al XML original
nodo=`grep " NumCert=\".*\"" $FILE_XML | sed -e "s/^.* NumCert/NumCert/"  | cut -f1 -d" "`
sed -e "s/$nodo/NumCert=\"$numcert\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

## Obtener sello
sello=`xsltproc $XSLTFILE $FILE_XML | openssl dgst -sha1 -sign $PEMFILE | openssl enc -base64 -A > $TMP`
sello=`sed -e "s/\\//\\\\\\\\\//g" $TMP`


nodo=`grep " Cert=\".*\"" $FILE_XML | sed -e "s/^.* Cert/Cert/" | cut -f1 -d" "`
sed -e "s/ $nodo/ Cert=\"$certificado\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`


nodo=`grep " Sello=\".*\"" $FILE_XML | sed -e "s/^.* Sello/Sello/" | cut -f1 -d" "`
sed -e "s/$nodo/Sello=\"$sello\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`


## Convertir a base 64 el XML para ser timbrado
B64STR=`base64 -i $FILE_XML`

## Armar la peticion SOAP
SOAP_REQUEST=$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:enc="http://www.w3.org/2003/05/soap-encoding"><env:Body><ns1:requestTimbrarCFDI env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"><param0 xsi:type="enc:Struct"><UserPass xsi:type="xsd:string">$USERPASS</UserPass><UserID xsi:type="xsd:string">$USERID</UserID><emisorRFC xsi:type="xsd:string">$RFC</emisorRFC><text2CFDI xsi:type="xsd:string">$B64STR</text2CFDI><generarTXT xsi:type="xsd:boolean">$GENERARTXT</generarTXT><generarPDF xsi:type="xsd:string">$GENERARPDF</generarPDF><generarCBB xsi:type="xsd:boolean">$GENERARCBB</generarCBB></param0></ns1:requestTimbrarCFDI></env:Body></env:Envelope>
EOF
)

echo $SOAP_REQUEST > $FILE_SOAPREQUEST
echo "Solicitando Timbrado..."
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO`
#echo $soap_response

echo $soap_response > $FILE_RESPONSE

## Verificar que no haya ocurrido un error
code=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Value/<env:Value/" | cut -f2 -d">" | cut -f1 -d"<"`
message=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Text/<env:Text/" | cut -f2 -d">" | cut -f1 -d"<"`
if [ "$code" != "" ]
    then
    echo "Codigo de error: "$code
    echo "Mensaje de error: "$message
    exit
fi

## Decodificar XML
xmlb64=`grep "<xml xsi:type=\"xsd:string\">.*<.xml>" $FILE_RESPONSE | sed -e "s/^.*<xml/<xml/" | cut -f2 -d">"| cut -f1 -d"<"`
echo `echo $xmlb64 | base64 --decode > $retencionesxml`

echo "Timbrado generado con exito"
echo "El comprobante lo encuentra en $retencionesxml"

if [ "$GENERARPDF" == "true" ]
    then
    pdfb64=`grep "<pdf xsi:type=\"xsd:string\">.*<.pdf>" $FILE_RESPONSE | sed -e "s/^.*<pdf/<pdf/" | cut -f2 -d">"| cut -f1 -d"<"`
    echo `echo $pdfb64 | base64 --decode > $retencionespdf`
    echo "El PDF lo encuentra en $retencionespdf"
fi

