#!/usr/bin/env nu
use grist.nu

if  not (["MAIL_SENDER", "MAIL_USER", "MAIL_PASSWORD", "MAIL_TABLE", "MAIL_BATCHSIZE"]|all {|c| $c in ($env|columns)}) {
    print "error: env is not set (see .env.example)"
    exit 1
}

let commentaires = grist records "Commentaire" --filter={"Script_mail": [True]} 
      | get records.fields 
      | update Proprietes_mail { $in | from json } 
      | update Date2 { $in * 1000000000 | into int | into datetime }

let messages = $commentaires | flatten Proprietes_mail.destinaires 
      | group-by Proprietes_mail.destinataire.email.0

let mails = $messages | transpose | rename destinataire commentaires

for mail in $mails {
  if $mail.destinataire in ['alice.pannetrat@beta.gouv.fr', 'christophe.ninucci@mail.numerique.gouv.fr'] { 
  let message = $mail.commentaires | get Proprietes_mail.message | str join "\n" 
  let body = $"Bonjour,\n\nvoici les commentaires Grist écrits à votre intention lors de la journée d'hier:\n\n($message)\n\nBonne journée :)"

  (curl --ssl-reqd --url "smtps://smtp.numerique.gouv.fr"
     --user $"($env.MAIL_USER):($env.MAIL_PASSWORD)"
     --mail-from $env.MAIL_USER
     --mail-rcpt $mail.destinataire 
     --header "Subject: Commentaires GRIST" 
     --header $"From: ($env.MAIL_USER)" 
     --header $"To: ($mail.destinataire)" 
     --form '=(;type=multipart/mixed' 
     --form $"=($body);type=text/plain" 
     --form '=)')
  }
}
