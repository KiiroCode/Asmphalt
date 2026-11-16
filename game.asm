;****************************************
;   ASMPHALT
; =======================================
;   Z Q S D ==> deplacement     * ==> quitter
;
;   Couleurs (palette VGA par defaut) :
;   2 herbe, 8 piste, 3 glace, 4 mur,
;   15 ligne de depart, 14 mi-parcours, 12 bot
;
;   Une seule convention de direction partout
;   (joueur, bot, circuit) : 0 droite, 1 bas, 2 gauche, 3 haut
;
;   Circuit "petit train" : liste d index de troncons poses
;   l un apres l autre sur une grille de cases de 40 x 40 pixels.
;   Le bot suit cette meme liste.
;****************************************
include LIBGFX.INC

pile    segment stack         ; Segment de pile
        DW 256 DUP(?)
pile    ends

donnees segment public  ; ******* Segment de donnees **********

; +++++++++++++++++++++++++++++++++++++++++++++
;               CONSTANTES
; +++++++++++++++++++++++++++++++++++++++++++++
include VOITURE.INC

TDROIT   EQU 0     ; tout droit
VDROITE  EQU 1     ; virage a droite (+1 quart de tour)
VGAUCHE  EQU 3     ; virage a gauche (+3 quarts = -1 quart de tour)
FINPIST  EQU 0FFh  ; fin de la liste
COLGLACE EQU 3     ; couleur de la glace (cyan)
COLBOT   EQU 12    ; carrosserie du bot (rouge clair)
BOTLENT  EQU 12    ; le bot saute 1 cycle sur 12 (plus grand = plus rapide)
DISTMIN  EQU 16    ; ecart en dessous duquel les voitures se touchent

; ============- CIRCUIT =======================
; grille 8 x 5 cases, depart case (2,4) vers la droite
piste DB TDROIT, TDROIT, TDROIT, TDROIT, VGAUCHE   ; ligne du bas
      DB TDROIT, TDROIT, VGAUCHE                   ; cote droit
      DB TDROIT, TDROIT, VDROITE, VGAUCHE          ; haut + coude
      DB TDROIT, VGAUCHE                           ; haut gauche
      DB TDROIT, TDROIT, TDROIT, VGAUCHE           ; cote gauche
      DB FINPIST

; ============- RECTANGLES ====================
; x, y, largeur-1, hauteur-1, couleur ... 0FFFFh = fin de liste
herbe DW   0,  0,319,199, 2, 0FFFFh
decor DW 140,164,  1, 31, 15          ; ligne de depart
      DW 220, 44,  1, 31, 14          ; ligne de mi-parcours
      DW  44,  4, 19, 41, COLGLACE    ; glace : coin haut gauche
      DW 124, 56, 35, 19, COLGLACE    ; glace : coude du haut
      DW 259, 46, 16, 51, COLGLACE    ; glace : cote droit
      DW 211,164, 45, 13, COLGLACE    ; glace : virage du bas (en L)
      DW 244,142, 12, 21, COLGLACE
      DW 0FFFFh
effGo DW 149,122, 21, 13, 2, 0FFFFh   ; efface le GO

; ouverture d une case selon le cote : x, y, largeur-1, hauteur-1
ouvTab DW 36,  4,  3, 31              ; 0 droite
       DW  4, 36, 31,  3              ; 1 bas
       DW  0,  4,  3, 31              ; 2 gauche
       DW  4,  0, 31,  3              ; 3 haut

; ============- TABLES PAR DIRECTION ==========
dirX    DW 1, 0, -1, 0                ; deplacement d un pixel
dirY    DW 0, 1, 0, -1
sprites DW voitD, voitB, voitG, voitH
touches DB 'dsqz'                     ; touche de chaque direction
chiffres DW ch1, ch2, ch3

; ============- TEXTES ========================
; 13, 10 = retour a la ligne (CharLine ajoute un 10 a la fin)
msgTouches DB '            A S M P H A L T', 13, 10
           DB '            ===============', 13, 10, 13, 10
           DB '   Z : haut          S : bas', 13, 10
           DB '   Q : gauche        D : droite', 13, 10
           DB '   * : quitter', 13, 10, 13, 10
           DB '   Glace (cyan) : impossible de tourner', 13, 10
           DB '   tant que tu es dessus, sauf contre un mur.', 13, 10, 13, 10
           DB '   Fais 3 tours avant le bot rouge !', 13, 10, 13, 10
           DB '   Depart dans 5 secondes...', 13, '$'
msgFin   DB 'Bravo ! Course terminee en 3 tours.$'
msgPerdu DB 'Perdu ! Le bot a fini avant toi.$'
msgQuit  DB 'A bientot !$'

; ============- TEXTE "TOUR" (23 x 7) =========
; 15 = blanc, 2 = vert (fond)
mTour DW   23,161
      DB   15, 15, 15, 15, 15,  2,  2, 15, 15, 15,  2,  2, 15,  2,  2,  2, 15,  2, 15, 15, 15, 15,  2
      DB    2,  2, 15,  2,  2,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15
      DB    2,  2, 15,  2,  2,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15
      DB    2,  2, 15,  2,  2,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15,  2, 15, 15, 15, 15,  2
      DB    2,  2, 15,  2,  2,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15,  2, 15,  2, 15,  2,  2
      DB    2,  2, 15,  2,  2,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15,  2, 15,  2,  2, 15,  2
      DB    2,  2, 15,  2,  2,  2,  2, 15, 15, 15,  2,  2,  2, 15, 15, 15,  2,  2, 15,  2,  2,  2, 15

; ============- TEXTE "GO" (11 x 7) ===========
mGo   DW   11,77
      DB    2, 15, 15, 15,  2,  2,  2, 15, 15, 15,  2
      DB   15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15
      DB   15,  2,  2,  2,  2,  2, 15,  2,  2,  2, 15
      DB   15,  2, 15, 15, 15,  2, 15,  2,  2,  2, 15
      DB   15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15
      DB   15,  2,  2,  2, 15,  2, 15,  2,  2,  2, 15
      DB    2, 15, 15, 15,  2,  2,  2, 15, 15, 15,  2

; ============- CHIFFRES (5 x 7) ==============
ch1   DW   5,35
      DB    2,  2, 15,  2,  2
      DB    2, 15, 15,  2,  2
      DB    2,  2, 15,  2,  2
      DB    2,  2, 15,  2,  2
      DB    2,  2, 15,  2,  2
      DB    2,  2, 15,  2,  2
      DB    2, 15, 15, 15,  2
ch2   DW   5,35
      DB    2, 15, 15, 15,  2
      DB   15,  2,  2,  2, 15
      DB    2,  2,  2,  2, 15
      DB    2,  2,  2, 15,  2
      DB    2,  2, 15,  2,  2
      DB    2, 15,  2,  2,  2
      DB   15, 15, 15, 15, 15
ch3   DW   5,35
      DB   15, 15, 15, 15,  2
      DB    2,  2,  2,  2, 15
      DB    2,  2,  2,  2, 15
      DB    2, 15, 15, 15,  2
      DB    2,  2,  2,  2, 15
      DB    2,  2,  2,  2, 15
      DB   15, 15, 15, 15,  2

; +++++++++++++++++++++++++++++++++++++++++++++
;               VARIABLES
; +++++++++++++++++++++++++++++++++++++++++++++
; --- joueur (voie du bas sur la ligne de depart) ---
direction DB 0
posX  DW  93       ; coin haut gauche de la voiture
posY  DW  180
ancX  DW  93       ; position avant le deplacement
ancY  DW  180
colVoit DB 1       ; 1 bleu, 14 jaune si choc
bloque DB 0        ; 1 si mur touche au dernier deplacement
surGlace DB 0      ; 1 si le centre de la voiture est sur la glace
tour  DB  1        ; tour en cours (1 a 3)
milieu DB 0        ; 1 si la ligne jaune a ete franchie dans le bon sens
fond  DB  225 DUP(8)   ; piste sous le joueur (depart sur asphalte uni)

; --- bot (voie du haut, a cote du joueur) ---
botX  DW  93
botY  DW  165
ancBX DW  93
ancBY DW  165
botDir DB 0        ; direction
botPas DB 0        ; pixels parcourus depuis le dernier virage possible
botIdx DW 0        ; index du troncon courant dans piste
botTour DB 0       ; passages sur la case de la ligne de depart
botCompt DB 0      ; compteur de cycles pour le ralentir
fondBot DB 225 DUP(8)  ; piste sous le bot

; --- majVoit ---
anc   DW  0, 0, 0  ; ancienne case de la voiture : x, y, adresse du fond
autre DW  0, 0, 0  ; case de l autre voiture    : x, y, adresse du fond
nouv  DW  0, 0, 0  ; nouvelle case              : x, y, (inutilise)
sprite DW 0        ; adresse du sprite
colDess DB 1       ; couleur de carrosserie
seulVoit DB 0      ; 1 : ne repeindre que la voiture (pas la piste)
dedans DB 0        ; resultat de dansCase
proche DB 0        ; 1 si les voitures se touchent
fondTmp DB 225 DUP(0)  ; fond de la nouvelle case, en construction
finX  DW  0
finY  DW  0

; --- temps ---
nbTicks DW 0       ; duree a attendre (18 ticks = environ 1 s)
debTick DW 0       ; tick de depart

; --- pose du circuit ---
curX  DW  0        ; coin haut gauche de la case en cours
curY  DW  0
cap   DB  0        ; direction du circuit
typeT DB  0        ; rotation du troncon en cours

donnees ends    ; ********** FIN Segment de donnees ************

; +++++++++++++++++++++++++++++++++++++++++++++
;               PROGRAMME
; +++++++++++++++++++++++++++++++++++++++++++++
code    segment public        ; Segment de code
assume  cs:code,ds:donnees,es:code,ss:pile

prog:
    mov AX, donnees         ; set DS on program data segment
    mov DS, AX

    call ecranTouches       ; 5 s en mode texte
    CALL Video13h           ; 320x200
    call circuit
    mov hX, 130             ; texte TOUR
    mov hY, 93
    mov BX, offset mTour
    CALL drawIconBig
    call afficheTour
    call majBot             ; premier dessin des voitures
    call majJoueur
    call decompte           ; 3, 2, 1, GO
    mov tempo, 2

; ========== GAME LOOP ===============
; 1. on deplace (voitures encore affichees)
; 2. on redessine le bot puis le joueur, sans jamais les effacer
; 3. si elles se touchent, on repeint le bot puis le joueur par-dessus
; 4. on regarde la piste sous le joueur (glace, lignes)
gameloop:
    call sleep
    call interact
    call bouge
    call bougeBot
    call majBot
    call majJoueur
    call proches
    cmp proche, 1
    jne glTours
    mov seulVoit, 1         ; repeint seulement les voitures, sur place
    mov AX, botX
    mov ancBX, AX
    mov AX, botY
    mov ancBY, AX
    mov AX, posX
    mov ancX, AX
    mov AX, posY
    mov ancY, AX
    call majBot
    call majJoueur
    mov seulVoit, 0
glTours:
    call tours
    jmp gameloop
; ====================================

; =============================
;      ECRANS ET TEMPS
; =============================
;------- ecranTouches ---------------
; affiche les touches en mode texte pendant 5 secondes
ecranTouches:
    call ClearScreen
    mov DX, offset msgTouches
    call CharLine
    mov nbTicks, 91         ; 5 x 18,2 = 91 ticks
    jmp attendTicks

;------- decompte ---------------
; 3, 2, 1 (1 s chacun) puis GO, au centre du circuit
decompte:
    mov hX, 155
    mov hY, 122
    mov BX, offset ch3
    call montre
    mov BX, offset ch2
    call montre
    mov BX, offset ch1
    call montre
    mov hX, 149
    mov BX, offset mGo
    call drawIconBig
    mov nbTicks, 9          ; GO pendant une demi-seconde
    call attendTicks
    mov SI, offset effGo
    call rects
vide:
    call PeekKey            ; oublie les touches tapees pendant l attente
    cmp userinput, 0
    jne vide
    RET
montre:                     ; dessine l icone BX et attend 1 s
    call drawIconBig
    mov nbTicks, 18

;------- attendTicks ---------------
; attend nbTicks ticks de l horloge BIOS (18,2 ticks par seconde)
; INT 1Ah, AH = 00h : CX:DX = nombre de ticks depuis minuit
; nbTicks >>
attendTicks:
    mov AH, 0
    int 1Ah
    mov debTick, DX
atBoucle:
    mov AH, 0
    int 1Ah
    mov AX, DX
    sub AX, debTick         ; ticks ecoules
    cmp AX, nbTicks
    jb atBoucle
    RET

;------- afficheTour ---------------
; tour >>
afficheTour:
    mov hX, 182
    mov hY, 93
    mov BL, tour
    mov BH, 0
    dec BX                  ; tour 1 -> case 0 de la table
    shl BX, 1               ; une adresse = 2 octets
    mov BX, chiffres[BX]
    jmp drawIconBig

; =============================
;      CIRCUIT
; =============================
;------- circuit ---------------
; herbe, puis les troncons de piste, puis lignes et glace
circuit:
    mov SI, offset herbe
    call rects
    mov curX, 80            ; case de depart (2,4)
    mov curY, 160
    mov cap, 0              ; vers la droite
    mov SI, offset piste
crTroncon:
    mov AL, [SI]
    cmp AL, FINPIST
    je crDecor
    call troncon
    inc SI
    jmp crTroncon
crDecor:
    mov SI, offset decor

;------- rects ---------------
; dessine une liste de rectangles : x, y, largeur-1, hauteur-1, couleur
; SI >>
rects:
    mov AX, [SI]
    cmp AX, 0FFFFh          ; fin de liste ?
    je rcFin
    mov Rx, AX
    mov AX, [SI+2]
    mov Ry, AX
    mov AX, [SI+4]
    mov Rw, AX
    mov AX, [SI+6]
    mov Rh, AX
    mov AX, [SI+8]
    mov col, AL
    call fillRect
    add SI, 10              ; rectangle suivant (5 mots)
    jmp rects
rcFin:
    RET

;------- troncon ---------------
; pose un troncon dans la case curX, curY puis passe a la case suivante.
; Meme routine pour tout droit et virages : seul le changement de cap differe.
; AL = rotation, curX, curY, cap >> curX, curY, cap
troncon:
    mov typeT, AL
    mov AX, curX            ; case pleine de mur (40 x 40)
    mov Rx, AX
    mov AX, curY
    mov Ry, AX
    mov Rw, 39
    mov Rh, 39
    mov col, 4
    call fillRect
    add Rx, 4               ; carre de piste au centre (32 x 32)
    add Ry, 4
    mov Rw, 31
    mov Rh, 31
    mov col, 8
    call fillRect
    mov AL, cap             ; ouvre l entree : cote oppose au cap
    add AL, 2
    call ouvre
    mov AL, cap             ; nouveau cap = cap + rotation
    add AL, typeT
    and AL, 3
    mov cap, AL
    call ouvre              ; ouvre la sortie : cote du nouveau cap
    mov BL, cap             ; case suivante : 40 pixels dans le sens du cap
    mov BH, 0
    shl BX, 1
    mov CX, 40
    mov AX, dirX[BX]
    imul CX                 ; AX = dirX x 40
    add curX, AX
    mov AX, dirY[BX]
    imul CX
    add curY, AX
    RET

;------- ouvre ---------------
; prolonge la piste jusqu au bord de la case (bande de 4 pixels)
; AL = cote (pris modulo 4), curX, curY >>
ouvre:
    and AL, 3
    mov BL, AL
    mov BH, 0
    mov CL, 3
    shl BX, CL              ; 4 mots = 8 octets par cote
    mov AX, curX
    add AX, ouvTab[BX]
    mov Rx, AX
    mov AX, curY
    add AX, ouvTab[BX+2]
    mov Ry, AX
    mov AX, ouvTab[BX+4]
    mov Rw, AX
    mov AX, ouvTab[BX+6]
    mov Rh, AX
    jmp fillRect            ; col vaut deja 8

; =============================
;      AFFICHAGE DES VOITURES
; =============================
;------- majJoueur / majBot ---------------
; preparent anc, autre, nouv, couleur et sprite, puis majVoit
majJoueur:
    mov AX, ancX
    mov anc, AX
    mov AX, ancY
    mov anc+2, AX
    mov anc+4, offset fond
    mov AX, botX            ; le bot a deja ete redessine
    mov autre, AX
    mov AX, botY
    mov autre+2, AX
    mov autre+4, offset fondBot
    mov AX, posX
    mov nouv, AX
    mov AX, posY
    mov nouv+2, AX
    mov AL, colVoit
    mov colDess, AL
    mov AL, direction
    jmp majVoiture
majBot:
    mov AX, ancBX
    mov anc, AX
    mov AX, ancBY
    mov anc+2, AX
    mov anc+4, offset fondBot
    mov AX, ancX            ; le joueur est encore a l ancienne place
    mov autre, AX
    mov AX, ancY
    mov autre+2, AX
    mov autre+4, offset fond
    mov AX, botX
    mov nouv, AX
    mov AX, botY
    mov nouv+2, AX
    mov colDess, COLBOT
    mov AL, botDir
majVoiture:
    mov AH, 0
    mov SI, AX
    shl SI, 1
    mov AX, sprites[SI]     ; sprite de la direction AL
    mov sprite, AX

;------- majVoit ---------------
; deplace une voiture SANS jamais l effacer :
; 1. chaque pixel de la nouvelle case est peint une seule fois :
;    la voiture, ou la piste si le sprite est transparent (255).
;    La piste dessous est gardee dans fondTmp.
; 2. on remet la piste la ou la voiture n est plus
; 3. fondTmp devient le fond de la voiture
; anc, autre, nouv, sprite, colDess, seulVoit >>
majVoit:
    mov BX, sprite
    add BX, 4               ; saute largeur et nombre de pixels
    mov DI, offset fondTmp
    mov AX, nouv+2
    mov cDX, AX
    add AX, 15
    mov finY, AX
mvLigne:
    mov AX, nouv
    mov cCX, AX
    add AX, 15
    mov finX, AX
mvPixel:
    call pisteSous          ; AL = piste sous ce pixel
    mov [DI], AL
    mov AH, [BX]            ; pixel du sprite
    cmp AH, 255
    jne mvVoit
    cmp seulVoit, 1         ; transparent : on peint la piste,
    je mvSuite              ; sauf si on ne repeint que la voiture
    mov col, AL
    jmp mvPeint
mvVoit:
    cmp AH, 1               ; carrosserie ?
    jne mvCouleur
    mov AH, colDess
mvCouleur:
    mov col, AH
mvPeint:
    call PaintPxl
mvSuite:
    inc BX
    inc DI
    inc cCX
    mov AX, cCX
    cmp AX, finX            ; fin de ligne ?
    jl mvPixel
    inc cDX
    mov AX, cDX
    cmp AX, finY            ; fin du carre ?
    jl mvLigne
; --- 2. piste remise la ou la voiture n est plus ---
    mov BX, anc+4           ; ancien fond
    mov AX, anc+2
    mov cDX, AX
    add AX, 15
    mov finY, AX
mvALigne:
    mov AX, anc
    mov cCX, AX
    add AX, 15
    mov finX, AX
mvAPixel:
    mov SI, offset nouv
    call dansCase
    cmp dedans, 1           ; recouvert par la nouvelle case ?
    je mvASuite
    mov AL, [BX]
    mov col, AL
    call PaintPxl
mvASuite:
    inc BX
    inc cCX
    mov AX, cCX
    cmp AX, finX
    jl mvAPixel
    inc cDX
    mov AX, cDX
    cmp AX, finY
    jl mvALigne
; --- 3. fondTmp devient le fond de la voiture ---
    mov SI, offset fondTmp
    mov BX, anc+4
    mov CX, 225
mvCopie:
    mov AL, [SI]
    mov [BX], AL
    inc SI
    inc BX
    loop mvCopie            ; dec CX, recommence si CX <> 0
    RET

;------- pisteSous ---------------
; couleur de la piste sous le pixel cCX, cDX, sans les voitures :
; dans l ancien fond, sinon dans le fond de l autre voiture,
; sinon a l ecran (pixel ou aucune voiture n est dessinee)
; cCX, cDX, anc, autre >> AL
pisteSous:
    mov SI, offset anc
    call dansCase
    cmp dedans, 1
    je psConnu
    mov SI, offset autre
    call dansCase
    cmp dedans, 1
    je psConnu
    call ReadPxl
    mov AL, rdcol
    RET
psConnu:
    mov AL, [SI]
    RET

;------- dansCase ---------------
; le pixel cCX, cDX est-il dans la case 15 x 15 decrite en SI (x, y, fond) ?
; si oui : SI = adresse de ce pixel dans le fond (ligne x 15 + colonne)
; cCX, cDX, SI >> dedans, SI
dansCase:
    mov dedans, 0
    mov AX, cDX
    sub AX, [SI+2]          ; ligne dans la case
    cmp AX, 0
    jl dcFin
    cmp AX, 14
    jg dcFin
    mov DL, 15
    mul DL                  ; AX = ligne x 15
    mov DX, cCX
    sub DX, [SI]            ; colonne dans la case
    cmp DX, 0
    jl dcFin
    cmp DX, 14
    jg dcFin
    add AX, DX
    add AX, [SI+4]          ; + adresse du fond
    mov SI, AX
    mov dedans, 1
dcFin:
    RET

;------- proches ---------------
; les voitures se touchent si leurs ecarts en X et en Y
; sont tous les deux plus petits que DISTMIN
; posX, posY, botX, botY >> proche
proches:
    mov proche, 0
    mov AX, posX
    sub AX, botX
    cmp AX, -DISTMIN
    jle prFin
    cmp AX, DISTMIN
    jge prFin
    mov AX, posY
    sub AX, botY
    cmp AX, -DISTMIN
    jle prFin
    cmp AX, DISTMIN
    jge prFin
    mov proche, 1
prFin:
    RET

; =============================
;      DEPLACEMENTS
; =============================
;------- interact ---------------
; sur la glace, les touches de direction sont ignorees
; sauf si la voiture est contre un mur (bloque = 1)
; surGlace, bloque >> direction
interact:
    call PeekKey
    mov AL, userinput
    cmp AL, '*'
    jne itGlace
    mov DX, offset msgQuit
    jmp finJeu
itGlace:
    cmp surGlace, 1         ; sur la glace ?
    jne itTouche
    cmp bloque, 1           ; contre un mur ?
    jne itFin               ; glace sans mur : on ne tourne pas
itTouche:
    or AL, 20h              ; majuscule -> minuscule
    mov SI, 0
itCherche:
    cmp AL, touches[SI]     ; touche de la direction SI ?
    je itTrouve
    inc SI
    cmp SI, 4
    jne itCherche
itFin:
    RET
itTrouve:
    mov AX, SI
    mov direction, AL
    RET

;------- bouge ---------------
; avance d un pixel, sauf si un mur est touche
; direction >> ancX, ancY, posX, posY, colVoit, bloque
bouge:
    mov AX, posX
    mov ancX, AX
    mov AX, posY
    mov ancY, AX
    mov BL, direction
    mov BH, 0
    shl BX, 1
    mov AX, dirX[BX]
    add posX, AX
    mov AX, dirY[BX]
    add posY, AX
    call testMur
    mov colVoit, 1          ; voiture bleue
    cmp bloque, 1
    jne bgFin
    mov AX, ancX            ; mur : on revient en arriere
    mov posX, AX
    mov AX, ancY
    mov posY, AX
    mov colVoit, 14         ; voiture jaune
bgFin:
    RET

;------- testMur ---------------
; lit 16 pixels dans le carre de la voiture
; (colonnes 1, 5, 9, 13 et lignes 1, 5, 9, 13)
; ecart de 4 = epaisseur d un mur : aucun bout de mur ne passe entre deux points
; posX, posY >> bloque
testMur:
    mov bloque, 0
    mov AX, posY
    add AX, 14
    mov finY, AX
    mov AX, posY
    add AX, 1
    mov cDX, AX
tmLigne:
    mov AX, posX
    add AX, 14
    mov finX, AX
    mov AX, posX
    add AX, 1
    mov cCX, AX
tmPixel:
    call ReadPxl
    cmp rdcol, 4            ; mur ?
    jne tmSuite
    mov bloque, 1
    RET
tmSuite:
    add cCX, 4
    mov AX, cCX
    cmp AX, finX
    jl tmPixel
    add cDX, 4
    mov AX, cDX
    cmp AX, finY
    jl tmLigne
    RET

;------- tours ---------------
; regarde la piste sous le centre de la voiture,
; dans le tableau fond (ligne 7, colonne 7 : 7 x 15 + 7 = 112)
; Les deux lignes sont sur des routes horizontales :
;   ligne blanche : bon sens = droite (0)
;   ligne jaune   : bon sens = gauche (2)
;   direction horizontale mais pas la bonne = demi-tour : mi-parcours annule
; fond, direction >> surGlace, milieu, tour
tours:
    mov AL, fond+112
    mov surGlace, 0
    cmp AL, COLGLACE        ; glace ?
    jne trJaune
    mov surGlace, 1
    RET
trJaune:
    cmp AL, 14              ; ligne jaune ?
    jne trBlanc
    cmp direction, 2
    jne trInverse
    mov milieu, 1
    RET
trBlanc:
    cmp AL, 15              ; ligne de depart ?
    jne trFin
    cmp direction, 0
    jne trInverse
    cmp milieu, 1           ; mi-parcours passe ?
    jne trFin
    mov milieu, 0
    cmp tour, 3             ; dernier tour ?
    je gagne
    inc tour
    jmp afficheTour
trInverse:
    test direction, 1       ; 1 ou 3 : on longe la ligne, rien a faire
    jnz trFin
    mov milieu, 0           ; demi-tour sur la ligne
trFin:
    RET

;------- fin du jeu ---------------
gagne:
    mov DX, offset msgFin
    jmp finJeu
perdu:
    mov DX, offset msgPerdu
finJeu:                     ; DX = message a afficher
    call VideoCMD
    call CharLine
    mov AX, 4C00h           ; fin de programme DOS, code 0
    int 21h

;------- bougeBot ---------------
; le bot roule toujours a la meme distance du centre de la piste.
; Il avance d un pixel, sauf 1 cycle sur BOTLENT.
; Tous les 40 pixels il change de case : il lit le troncon et tourne.
; Arrive sur la case de la ligne de depart (index 1) : un passage de plus.
; >> ancBX, ancBY, botX, botY, botDir, botTour
bougeBot:
    mov AX, botX
    mov ancBX, AX
    mov AX, botY
    mov ancBY, AX
    inc botCompt
    cmp botCompt, BOTLENT
    jne bbAvance
    mov botCompt, 0
    RET                     ; ce cycle-ci, le bot ne bouge pas
bbAvance:
    mov BL, botDir
    mov BH, 0
    shl BX, 1
    mov AX, dirX[BX]
    add botX, AX
    mov AX, dirY[BX]
    add botY, AX
    inc botPas
    cmp botPas, 40          ; case suivante ?
    jne bbFin
    mov botPas, 0
    inc botIdx
    mov BX, botIdx
    mov AL, piste[BX]
    cmp AL, FINPIST         ; bout de la liste : on reboucle
    jne bbTourne
    mov botIdx, 0
    mov AL, piste
bbTourne:
    add AL, botDir          ; meme calcul que pour poser le circuit
    and AL, 3
    mov botDir, AL
    cmp botIdx, 1           ; case de la ligne de depart ?
    jne bbFin
    inc botTour
    cmp botTour, 4          ; 1er passage = depart, puis 3 tours
    jne bbFin
    jmp perdu               ; trop loin pour un saut conditionnel
bbFin:
    RET

; ================= FIN DU CODE ===============

code    ends                   ; Fin du segment de code
end prog                         ; Fin du programme