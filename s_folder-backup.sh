#!/bin/bash
#
# Filename: s_folder-backup.sh
#
# Created: 28/10/2021 (16:50:39)
# Created by: Lorenzo Saibal Forti <lorenzo.forti@gmail.com>
#
# Last Updated: 29/10/2021 (11:16:26)
# Updated by: Lorenzo Saibal Forti <lorenzo.forti@gmail.com>
#
# Comments: bash 4 required
#
# Copyleft: 2021 - Tutti i diritti riservati
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#=====================================================================

#=====================================================================
# General config
# Configurazione generale
#=====================================================================

# a space separated list of folders (including path)
# lista delle cartelle di cui eseguire il backup (separate da spazio e con path)
FOLDERS='/home/saibal/Documenti/'

# working directory where to store backup folders (no trailing slash). check r/w permissions for the user
# directory dove salvare i backup (senza slash finale). controllare i permessi di scrittura sulla cartella
OUT_DIR='/home/saibal/Scaricati'

# data format (it or en)
# formato data (it oppure en)
DATE_FORMAT='IT'

# "last backup" folder name
# cartella ultimo backup
LAST_FOLDER='last'

# daily backup? (y or n)
# backup giornaliero? (y oppure n)
DAILY_BACKUP='y'

# "daily backup" folder name. check r/w permissions for the user
# cartella backup giornalieri. controllare i permessi di scrittura sulla cartella
DAILY_FOLDER='daily'

# daily backup? (y or n)
# backup mensile? (y oppure n)
MONTHLY_BACKUP='y'

# "monthly backup" folder name. check r/w permissions for the user
# cartella backup mensili. controllare i permessi di scrittura sulla cartella
MONTHLY_FOLDER='monthly'

# day of month of monthly backup (e.g. 01 02 03 ... 29 30 31). usefull if crontab runs every day
# giorno del mese in cui effettuare il backup mensile (formato 01, 02, 03, etc)
MONTHLY_BKDAY='01'

#=====================================================================
# Log Configuration
# Configurazione logs
#=====================================================================
# save log? (y or n)
# registrazione dei log? (y oppure n)
LOGS_REC='y'

# directory where to store log files. if empty value, it uses backup's directory (no trailing slash).
# directory dove salvare i LOG. Se lasciata vuota sarà la stessa dei backup (senza slash finale).
LOGS_DIR='/home/saibal'

# log folder name. check r/w permissions for the user
# cartella dei LOG. controllare i permessi di scrittura sulla cartella
LOGS_FOLDER='[log]'

# log filename
# nome del file di LOG
LOGS_FILENAME='folder-backup.log'

# max size of the log file (in KB)
# dimensione massima del file di log (in KB)
LOGS_MAXSIZE='900'

#=====================================================================
# Email configuration
# Configurazione invio email
#=====================================================================
# enable email service as notification? (y or n)
# abilitare invio email con risultato delle operazioni? (y oppure n)
EMAIL_SEND='y'

# enable email only for errors? (y or n)
# inviare email solo in caso di errore? (y oppure n)
EMAIL_ONLYERRORS='y'

# email service. usually I use "ssmtp". try with "smtp" or another service but I don't guarantee
# programma da utilizzare per l'invio dell'email
EMAIL_SERVICE='ssmtp'

# email recipient
# destinatario email
EMAIL_RECIVER='email@gmail.com'

# email subject
# soggetto email
EMAIL_SUBJECT='File System Backup - Report'

#=====================================================================
# Messages configuration
# Configurazione messaggi
#=====================================================================
# result messages writed in log files. FOLDERNAME is a placeholder.
# messaggi di ritorno per il backup (IP e FOLDERNAME sono placeholder)
BACKUP_OK="BACKUP DONE!   | IP | All backups done successfully"
BACKUP_KO="BACKUP ERROR!  | IP | The following folders: FOLDERNAME haven't been processed"
SEMAIL_KO="SENDING ERROR! | IP | Can't find $EMAIL_SERVICE to send email"

########################################
# NOTHING TO EDIT
# NIENTE DA MODIFICARE
########################################

# di default hostname utilizza il trattino come separatore. cambio con il punto
IP=$(hostname -I | cut -d ' ' -f1)

BACKUP_OK=${BACKUP_OK//IP/$IP}
BACKUP_KO=${BACKUP_KO//IP/$IP}
SEMAIL_KO=${SEMAIL_KO//IP/$IP}

#=========================================
# FUNZIONI VARIE
#=========================================
# crea una cartella. $1 è il nome della cartella
create_folder() {

	# controllo l'esistenza della cartella
	if [ ! -d "$1" ]
	then

		if ! mkdir -p "$1" > /dev/null 2>&1
		then

			echo "Creation error for the file/folder \"$1\". Check doesn't exist a file/folder with same name"
			exit
		fi
	fi
}

# effettua la compressione del file o folder passato come parametro $2. il param $1 è il nome del file compresso
# utilizzo tar perchè di default mi mantiene la struttura delle directory
create_archive() {

	# comprimo il tutto con tar
	tar zcfP "$1" "$2"

	# risultato operazione
	ARCHIVE_ERROR=$?

	return $ARCHIVE_ERROR
}

# genere un nome univoco del path passato come parametro
# il nome generato è "parte iniziale" path (se presente) + "parte finale" path + indice numerico passato come parametro (lo prendo dall'index del ciclo for)
# $1 è il path della cartella. $2 è l'indice
get_filename() {

	IFS='/' read -ra result <<< "$1"

    if [ "${#result[@]}" -le 2 ]
    then
        FILENAME="${result[-1]}"
    else
		FILENAME="${result[1]}-${result[-1]}"
	fi

	FILENAME="${FILENAME}__[id-${2}]"

	# FILENAME=$(echo $FILENAME | sed -e 's/\//-/g')
}

# funzione per check invio email
check_email_service() {

	if [ "${EMAIL_SEND,,}" = 'y' ]
	then

		CHECK_MAIL=$(command -v "$EMAIL_SERVICE")

		if [ -n "$CHECK_MAIL" ]
		then
			MAIL_RESULT=1
		else
			MAIL_RESULT=0
			# aumento il contatore
			ERROR_NOMAIL_SERVICE=$(( ERROR_NOMAIL_SERVICE + 1 ))
		fi

	else
		MAIL_RESULT=0
	fi

	return $MAIL_RESULT
}

# funzione per inviare email | eliminato il campo From: per problemi con google come proxy. anche il campo To va tolto
# $1 $EMAIL_SERVICE | $2 $EMAIL_RECIVER | $3 SOGGETTO | $4 $EMAIL_MSG
send_mail() {

	# alternativa
	echo -e "From: sh-script\nSubject: $3\n\n$4" | "$1" "$2"
}

#=========================================
# VARIABILI
#=========================================
# path principali del sistema
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin:/usr/sbin

# extension for tar file. no start dot
# estensione per il file compresso. senza punto iniziale
ARCHIVE_EXT='tar.gz'

# data di oggi
TODAY_DATE=$(date +%d/%m/%Y)

# ora di oggi
TODAY_TIME=$(date +%T)

# giorno della settimana (1 Lunedì, 2 Martedì, 3 Mercoledì etc etc)
NDAY=$(date +%u)

# giorno del mese (formato 01, 02, 03, etc)
DMON=$(date +%d)

# mese
MON=$(date +%m)

# mese - anno
MONYEA=$(date +%m_%Y)

# date esecuzione backup nei due formati
DATEIT=$(date +\[%d-%m-%Y__%H:%M:%S\])
DATEEN=$(date +\[%Y-%m-%d__%H:%M:%S\])

# formato data per i log
LOGDATE="$(date +%Y/%m/%d) - $(date +%T)"

# contatori
ITER=1
ERROR_COUNT_SINGLE=0
ERROR_COPY=0
ERROR_NOMAIL_SERVICE=0

# se non esiste la directory LAST la creo
create_folder "$OUT_DIR/$LAST_FOLDER"

# se non esiste la directory DAILY la creo
if [ "${DAILY_BACKUP,,}" = 'y' ]
then
	create_folder "$OUT_DIR/$DAILY_FOLDER"
fi

# se non esiste la directory MONTHLY la creo
if [ "${MONTHLY_BACKUP,,}" = 'y' ]
then
	create_folder "$OUT_DIR/$MONTHLY_FOLDER"
fi

# scelgo la formattazione della data
if [ "${DATE_FORMAT,,}" = 'it' ]
then
	DATE="$DATEIT"
else
	DATE="$DATEEN"
fi

# se sono abilitati i logs e non esiste la directory LOGS la creo e calcolo la dimensione massima del file
if [ "${LOGS_REC,,}" = 'y' ]
then

	# se la variabile LOGS_DIR non è vuota la imposto altrimenti inserisco la cartella dentro la directory di default
	if [ -z "$LOGS_DIR" ]
	then
		LOGS_DIR="$OUT_DIR"
	fi

	# creo la directory log
	create_folder  "$LOGS_DIR/$LOGS_FOLDER"

	# creo il file di log
	if [ ! -f "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME" ]
	then
		echo -ne > "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME"
	fi

	# converto i KB in BYTES dopo aver controllato che la VAR non sia vuota
	if [ -n "$LOGS_MAXSIZE" ]
	then
		LOGS_MAXBYTES=$(( LOGS_MAXSIZE*1000 ))
	else
		LOGS_MAXBYTES=$(( 1000*1000 ))
	fi
fi

#=========================================
# START BACKUP NOW!!!
#=========================================

# Controllo l'invio delle email. ritorna $MAIL_RESULT
check_email_service

# inizio il ciclo sui database
for file in $FOLDERS
do
		########################################
		# BACKUP LAST
		########################################

		get_filename "$file" $ITER

		# rimuovo i vecchi backup last
		rm -f "$OUT_DIR/$LAST_FOLDER/${FILENAME}__[last]"*".${ARCHIVE_EXT}"

		# creo il nome del file che verrà compresso
		OUTFILE="$OUT_DIR/$LAST_FOLDER/${FILENAME}__[last]__${DATE}.${ARCHIVE_EXT}"

		# comprimo il file. ritorna $ARCHIVE_ERROR
		create_archive "$OUTFILE" "$file"

		# se la compressione è ok copio l'ultimo tar dentro la dir DAILY e MONTHLY
		if [ "$ARCHIVE_ERROR" -eq 0 ]
		then

			########################################
			# BACKUP GIORNALIERO
			########################################
			if [ "${DAILY_BACKUP,,}" = 'y' ]
			then

				# rimuovo i vecchi backup
				rm -f "$OUT_DIR/$DAILY_FOLDER/${FILENAME}__[day-${NDAY}]"*".${ARCHIVE_EXT}"

				# uso la funzione cp per copiare l'ultimo back dalla cartella "last" a "daily"
				cp "$OUTFILE" "$OUT_DIR/$DAILY_FOLDER/${FILENAME}__[day-${NDAY}]__${DATE}.${ARCHIVE_EXT}"

				# se le copia ha generato errori e i log sono attivi
				if [ $? -ne 0 ] && [ "${LOGS_REC,,}" = 'y' ]
				then

					# aumento il contatore
					ERROR_COPY=$(( ERROR_COPY + 1 ))

					# registro i folder nella stessa variabile
					ERROR_RESULT+="[${FILENAME}__day-${NDAY}] "
				fi
			fi

			########################################
			# BACKUP MENSILE
			########################################
			if [ "${MONTHLY_BACKUP,,}" = 'y' ] && [ "$DMON" = "$MONTHLY_BKDAY" ]
			then

				# rimuovo i vecchi backup
				rm -f "$OUT_DIR/$MONTHLY_FOLDER/${FILENAME}__[month-${MON}_"*".${ARCHIVE_EXT}"

				# uso la funzione cp per copiare l'ultimo back dalla cartella "last" a "monthly"
				cp "$OUTFILE" "$OUT_DIR/$MONTHLY_FOLDER/${FILENAME}__[month-${MONYEA}]__${DATE}.${ARCHIVE_EXT}"

				# se le copia ha generato errori e i log sono attivi
				if [ $? -ne 0 ] && [ "${LOGS_REC,,}" = 'y' ]
				then

					# aumento il contatore
					ERROR_COPY=$(( ERROR_COPY + 1 ))

					# registro i folder nella stessa variabile
					ERROR_RESULT+="[${FILENAME}__month-${MONYEA}] "
				fi
			fi
		fi

		# uso le VAR di ritorno delle funzioni per gestire gli errori nei log se abilitati
		if [ "$ARCHIVE_ERROR" -ne 0 ] && [ "${LOGS_REC,,}" = 'y' ]
		then

			# aumento il contatore
			ERROR_COUNT_SINGLE=$(( ERROR_COUNT_SINGLE + 1 ))

			# registro i folder nella stessa variabile
			ERROR_RESULT+="${FILENAME}__[last] "
		fi

		ITER=$(( ITER + 1 ))
done

#=========================================
# LOGS SECTION!!!
#=========================================
if [ "${LOGS_REC,,}" = 'y' ]
then

	echo ======================================================================
	echo Saibal Folder Backup
	echo
	echo Start time: "$TODAY_TIME" - "$TODAY_DATE"
	echo Backup of Folders \(powered by saibal - lorenzo.forti@gmail.com\)
	echo ======================================================================
	echo Result:
	echo

	# dimensione del file per vedere quando troncarlo
	LOG_SIZE=$( stat -c %s "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME")

	# se la misura attuale è più grande di quella massima tronco il file e ricomincio
	if [ "$LOG_SIZE" -gt "$LOGS_MAXBYTES" ]
	then

		# con il parametro -n non metto una riga vuota nel file
		echo -ne > "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME"
	fi

	# se vengono rilevati errori nel servizio di posta
	if [ "$ERROR_NOMAIL_SERVICE" -ne 0 ]
	then

		SEMAIL_KO="$LOGDATE | $SEMAIL_KO"

		echo "$SEMAIL_KO"
		echo "$SEMAIL_KO" >> "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME"
	fi

	# se tutti i backup sono OK stampo il messaggio relativo
	if [ "$ERROR_COUNT_SINGLE" -eq 0 ] && [ "$ERROR_COPY" -eq 0 ]
	then

		# replace di alcune variabili
		BACKUP_OK="$LOGDATE | $BACKUP_OK"

		echo "$BACKUP_OK"
		echo "$BACKUP_OK" >> "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME"

	# se i dump (last/mensile e/o giornaliero) fallisce stampo un determinato messaggio
	else

		if [ "$ERROR_COUNT_SINGLE" -ne 0 ] || [ "$ERROR_COPY" -ne 0 ]
		then

			BACKUP_KO="$LOGDATE | $BACKUP_KO"
			BACKUP_KO=${BACKUP_KO//FOLDERNAME/$ERROR_RESULT}

			echo "$BACKUP_KO"
			echo "$BACKUP_KO" >> "$LOGS_DIR/$LOGS_FOLDER/$LOGS_FILENAME"
		fi
	fi
fi

#=========================================
# MAIL SECTION!!!
#=========================================
if [ "$MAIL_RESULT" -eq 1 ]
then

	# se viene scelto di ricevere una email anche quando le operazioni sono OK
	if [ "${EMAIL_ONLYERRORS,,}" = 'n' ]
	then

		# se tutti i dump sono OK invio il messaggio relativo
		if [ "$ERROR_COUNT_SINGLE" -ne 0 ] && [ "$ERROR_COPY" -ne 0 ]
		then

			send_mail "$EMAIL_SERVICE" "$EMAIL_RECIVER" "$EMAIL_SUBJECT" "$BACKUP_OK"
		fi
	fi

	# invio email errore backup last, giornaliero o mensile
	if [ "$ERROR_COUNT_SINGLE" -ne 0 ] || [ "$ERROR_COPY" -ne 0 ]
	then

		BACKUP_KO=${BACKUP_KO//FOLDERNAME/$ERROR_RESULT}

		send_mail "$EMAIL_SERVICE" "$EMAIL_RECIVER" "$EMAIL_SUBJECT" "$BACKUP_KO"
	fi
fi

exit 0
