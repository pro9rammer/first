//
//  main.m
//  ProjectResValidationTool
//
//  Created by 요한 김 on 12. 11. 20..
//  Copyright (c) 2012년 요한 김. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <stdio.h>
#import <sys/stat.h>
#import <dirent.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>

static int indent = 0;
char cdir[256];

typedef struct resNode{
    
    char* name; // 리소스 파일 이름.
    char* dir;  // 디렉토리 경로.
    
    struct resNode *next;   // 다음 노드를 참조.
    
}RES_NODE;

RES_NODE *resNodeHead, *resNodeTail;      // 소스파일에서 참조하고 있는 리소스 파일 목록을 저장.
RES_NODE *existResHead, *existResTail;    // 실제로 존재하는 리소스 파일 목록을 저장(.png, @2x.png 등).

typedef struct srcNode{
    
    char* name; // 소스 파일 이름.
    char* dir; // 디렉토리 경로.
    RES_NODE *resNodeHead, *resNodeTail;    // 참조하고 있는 리소스파일 리스트. -> 추후 개별파일 참조 리소스 확인 기능 구현 때 사용.
    
    struct srcNode *next;   // 다음 노드를 참조.
    
}SRC_NODE;

SRC_NODE *srcNodeHead, *srcNodeTail;    // 전체 파일 조사.
SRC_NODE *targetSrcHead, *targetSrcTail;    // 토큰 뽑아낼 대상 파일만 저장(.m, .xib, .h 등).

SRC_NODE *searchSrc(SRC_NODE *this, char *key);
void    addSrc(SRC_NODE **head, SRC_NODE **tail, char *dirName, char *fileName);
void    delSrc(SRC_NODE **head, SRC_NODE **tail, char *key);
void    printSrcList(SRC_NODE *h);

RES_NODE *searchRes(RES_NODE *this, char *key);
void    addRes(RES_NODE **head, RES_NODE **tail, char *dirName, char *fileName);
void    delRes(RES_NODE **head, RES_NODE **tail, char *key);
void    printResList(RES_NODE *h);

int selectSrcBy(char *targetExt, SRC_NODE *srcHead, SRC_NODE **retHead, SRC_NODE **retTail);
int selectResBy(char *targetExt, SRC_NODE *srcHead, RES_NODE **retHead, RES_NODE **retTail);

void findReferResBy(char* targetExt, SRC_NODE *srcHead);

void myFunc(char *file);
void scanDir(char *wd, void(*func)(char*), int depth);
int findTokenBy(char* srcFile, char* startSymbol, char* endSymbol, char** result);
int findStringBy(char* srcString, char* startSymbol, char* endSymbol, char** result);

int checkResource(RES_NODE *refResHead, RES_NODE *existResHead);


int main(int argc, const char * argv[])
{

    @autoreleasepool { 
        
        printf("Project Resource Validation v0.1");
        
        scanDir((char*)argv[1], myFunc, 0);
        
        printSrcList(srcNodeHead);  // 스캔한 소스 리스트를 출력.
        
        // 검색대상이 될 소스 파일 리스트를 뽑아냄.
        selectSrcBy(".m", srcNodeHead, &targetSrcHead, &targetSrcTail); // .m 일 경우 .mp3 까지 검색됨. But, 결과엔 no matter.
        selectSrcBy(".h", srcNodeHead, &targetSrcHead, &targetSrcTail); //
        selectSrcBy(".xib", srcNodeHead, &targetSrcHead, &targetSrcTail);
        
        printSrcList(targetSrcHead);    // 뽑아낸 소스 파일 리스트를 출력.
        
        // 현재 가지고 있는(실제로 존재하는) 리소스 리스트를 뽑아냄.
        selectResBy(".png", srcNodeHead, &existResHead, &existResTail);
        
        printResList(existResHead);    // 뽑아낸 (실제로 존재하는)리소스 파일 리스트를 출력.
        
        // 소스 내부에서 참조하고 있는 리소스 리스트를 뽑아서 각 소스파일 노드에 저장함.
//        findReferResBy("png", targetSrcHead);
        findReferResBy("", targetSrcHead);
        
        printResList(resNodeHead);    // 참조하고 있는 리소스 파일 리스트를 출력.
        
        // 누락된 리소스 파일 확인 및 출력.
        printf("\nNo Resource : %d", checkResource(resNodeHead, existResHead));
        
    }
    
    return 0;
    
}


void addSrc(SRC_NODE **head, SRC_NODE **tail, char *dirName, char *fileName){
    
    SRC_NODE *new;
    
    if ((new = (SRC_NODE*)malloc(sizeof(SRC_NODE))) == NULL) {
        printf("Out of Memory.\n");
        return;
    }
    
    if (*tail != NULL) (*tail)->next = new;
    if (*head == NULL)  *head = new;
    *tail = new;
    (*tail)->next = NULL;
    
    (*tail)->dir = (char*)malloc((strlen(dirName)+1)*sizeof(char)); // 문자열 마지막의 '\0' 을 위해 +1 을 꼭 해줘야 한다.
    strcpy((*tail)->dir, dirName);
    (*tail)->name = (char*)malloc((strlen(fileName)+1)*sizeof(char));
    strcpy((*tail)->name, fileName);
    
}


SRC_NODE* searchSrc(SRC_NODE* this, char* key){
    
    while ( this != NULL ) {
        if (strcmp(this->name, key)==0) {
            return this;
        }
        this = this->next;
    }
    
    return NULL;
    
}


int selectSrcBy(char *targetExt, SRC_NODE *srcHead, SRC_NODE **retHead, SRC_NODE **retTail){

    printf("\n< Target Source Ext : %s >", targetExt);
    
    while ( srcHead != NULL ) {
        if (strstr(srcHead->name, targetExt) != NULL) {
            
            printf("\n%s / %s", srcHead->dir, srcHead->name);
            
            addSrc(retHead, retTail, srcHead->dir, srcHead->name);
            
        }
        
        srcHead = srcHead->next;
        
    }
    
    printf("\n- Source selection end -\n");
    
    return -1;
}


int selectResBy(char *targetExt, SRC_NODE *srcHead, RES_NODE **retHead, RES_NODE **retTail){
    
    printf("\n< Target Resource Ext : %s >", targetExt);
    
    while ( srcHead != NULL ) {
        if (strstr(srcHead->name, targetExt) != NULL) {
            
            printf("\n%s/%s", srcHead->dir, srcHead->name);
            
            addRes(retHead, retTail, srcHead->dir, srcHead->name);
            
        }
        
        srcHead = srcHead->next;
        
    }
    
    printf("\n- Resource selection end -");
    
    return -1;
}


void findReferResBy(char* targetExt, SRC_NODE *srcHead){
    
    printf("\n< Find Reference Resource in Source by : %s >\n", targetExt);

    char targetFilePath[256];
    
    while ( srcHead != NULL ) {
        
//        char* endSymbol = "." + targetext
        memset(targetFilePath, '\0', 256);
        
//        printf("%s / %s\n", srcHead->dir, srcHead->name);
        sprintf(targetFilePath, "%s/%s", srcHead->dir, srcHead->name);
//        printf("%s\n", targetFilePath);
        
        // .xib 파일일 경우
        if (strstr(srcHead->name, ".xib") != NULL){
//            endSymbol = "." + targetext + </"
            findTokenBy(targetFilePath, ">", ".png</", NULL);
        }
        // .m 파일일 경우
        else if (strstr(srcHead->name, ".m") != NULL){
            //            endSymbol = "." + targetext + </"
            findTokenBy(targetFilePath, "\"", ".png\"", NULL);
        }
        // .h 파일일 경우.
        else if (strstr(srcHead->name, ".h") != NULL){
            //            endSymbol = "." + targetext + </"
            findTokenBy(targetFilePath, "\"", ".png\"", NULL);
        }
        
        srcHead = srcHead->next;
        
    }
    
//    printResList(resNodeHead);
    
    printf("\n- Resource Finding end -");
    
}


#define MAX_COLS 32768

int findTokenBy(char* srcFile, char* startSymbol, char* endSymbol, char** result){
    
    FILE *in;
    
    char s[MAX_COLS];
    
    printf("File open : %s\n", srcFile);
    
    if ( (in = fopen(srcFile, "rt")) == NULL) {
            fputs("Cannot open input file...\n", stderr);
//        exit(1); // 모든 파일 닫고, 프로그램 종료
        return -1;
    }
    
    while (fgets(s, MAX_COLS, in) != NULL) {
//        printf("%s",s); // 한 줄씩 화면에 출력
//        findStringBy(s, ">", ".png</", NULL);
        findStringBy(s, startSymbol, endSymbol, NULL);
    }
    
    //printResList(resNodeHead);
    
//    fcloseall(); // 모든 파일 닫기
    return 0;

}


/*
 void delSrc(SRC_NODE **head, SRC_NODE **tail, char *key){
 
 SRC_NODE *this = *head, *last = NULL;
 
 while (this != NULL) {
 if(strcmp(this->name, key)==0){
 break;
 }
 last = this;
 this = this->next;
 }
 
 ...
 
 }
 */


void printSrcList(SRC_NODE *h){
    
    printf("\n\n< List of SRC nodes >\n");
    while( h != NULL ){
        printf("%s/%s\n",h->dir, h->name);
        h = h->next;
    }
    printf("- SRC List end -\n");
    
}


void addRes(RES_NODE **head, RES_NODE **tail, char *dirName, char *fileName){

    // 리스트 중복체크 필요.
    
    RES_NODE *new;
    
    if ((new = (RES_NODE*)malloc(sizeof(RES_NODE))) == NULL) {
        printf("Out of Memory.\n");
        return;
    }
    
    if (*tail != NULL) (*tail)->next = new;
    if (*head == NULL)  *head = new;
    *tail = new;
    (*tail)->next = NULL;
    
    (*tail)->dir = (char*)malloc((strlen(dirName)+1)*sizeof(char)); // 문자열 마지막의 '\0' 을 위해 +1 을 꼭 해줘야 한다.
    strcpy((*tail)->dir, dirName);
    (*tail)->name = (char*)malloc((strlen(fileName)+1)*sizeof(char));
    strcpy((*tail)->name, fileName);
    
}


RES_NODE* searchRes(RES_NODE* this, char* key){
    
    while ( this != NULL ) {
        if (strcmp(this->name, key)==0) {
            return this;
        }
        this = this->next;
    }
    
    return NULL;
    
}


/*
void delRes(RES_NODE **head, RES_NODE **tail, char *key){
    
    RES_NODE *this = *head, *last = NULL;
    
    while (this != NULL) {
        if(strcmp(this->name, key)==0){
            break;
        }
        last = this;
        this = this->next;
    }
 
 ...
     
}
*/


/*  노드 삭제   */
/*
void delsl(SLNODE **head, SLNODE **tail, char key){
    
    SLNODE *this = *head, *last = NULL;
    
    while(this != NULL){
        
        if(this->ch == key) break;
        last = this;
        this = this->next;
        
    }
    
    if(this == NULL){
        puts("\nNot found");
        return;
    }
    
    if(this != *head)
        last->next = this->next;
    else
        *head = (this->next != NULL) ? this->next : NULL;

    if( this == *tail ) *tail = last;

    free(this);

}
*/


void printResList(RES_NODE *h){
    
    printf("\n\n< List of RES nodes >\n");
    while( h != NULL ){
//        printf("%s/%s\n",h->dir, h->name);  // 디렉토리 경로와 같이 출력.
        printf("%s\n", h->name);  // 파일 이름만 출력.
        h = h->next;
    }
    printf("- RES List end -\n");
    
}


// Desc
// 특정문자열에서 특정문자 토큰(.png) 를 찾아서 리스트로 저장하고 찾은 갯수를 int 로 리턴한다.
// startSymbol 와 endSymbol 사이에 있는 문자열을 검색한다.
//
// Return
//  int : 찾은 갯수. ( -1 : 파라미터 오류)
//
// Params
//  char* srtString   : 작업 타겟 문자열
//  char* startSymbol : 시작 식별자
//  char* endSymbol   : 종료 식별자
//  char** result     : 찾은 결과 리스트를 저장
//
// Example
//  findStringBy("alkjdflajsf928r50219", "\"", ".png", refResList);
//
// Note
//  .xib 파일의 경우 .png 파일은 항상 <string> 과 </string> 태그(symbol) 사이에 위치한다.
//  .h 또는 .m 파일의 경우 .png 파일은 큰따옴표(",Double quoatation) 사이에 위치한다.
//
//  token 문자열 에 startSymbol 과 endSymbol 은 포함되지 않는다. 오직 그 사이의 문자열만 저장됨.

int findStringBy(char* srcString, char* startSymbol, char* endSymbol, char** result){
    
    int     foundCnt = 0;
    char*   targetString = srcString;
    char*   startPtr = NULL;
    
    
    // 파라미터 유효성 검증 필요
    //  에러시 return -1;
    
    while (1) {
        startPtr = strstr(targetString, endSymbol);
        
        if(startPtr==NULL){
            break;
        }
        
        if(startPtr){
            //  문자열 토큰을 골라내 리스트에 저장.
            
            int i;
            for(i=0 ; strncmp(startPtr, startSymbol, strlen(startSymbol))!=0 ; startPtr--, i++){
            }
            
//            printf("Found Token Length : %d\n", i);
            
            char* foundString = (char*)calloc(i, sizeof(char));
            
            if(foundString == NULL){
               printf("Out of memory!");
               exit(0);
            }
            
            strncat(foundString, startPtr+1 , i-1);
            
            printf("Found Token String : %s\n", foundString);
            
            addRes(&resNodeHead, &resNodeTail, "", foundString);    // 소스파일 내에서 참조할 때는 디렉토리명이 안쓰이므로.
            
//          free(foundString);
            
            targetString = startPtr + i + 1;
            
            foundCnt++;
            startPtr = NULL;
            
        }
        
    }
    
//    printResList(resNodeHead);
    
    return foundCnt;
    
}


void myFunc(char *file){
    
    printf("%s/%s\n", getcwd(cdir, 256), file);
    
}


void recursiveScanDir(char *targetDir, int depth){
    
}


void scanDir(char *wd, void (*func)(char*), int depth){
    
    struct dirent **items;
    int nitems, i;
    
    if(chdir(wd)<0){
        printf("DIR : %s\n",wd);
        perror("chdir");
        exit(1);
    }
    
    nitems = scandir(".", &items, NULL, alphasort);
    
    for(i=0; i<nitems; i++){
        struct stat fstat;
        
        if((!strcmp(items[i]->d_name, ".")) || (!strcmp(items[i]->d_name, ".."))){
            continue;
        }
        
//        func(items[i]->d_name); // print file path
        
        char dirPathBuf[256];
        memset(dirPathBuf, '\0', 256);
        sprintf(dirPathBuf, "%s", getcwd(cdir, 256));
//        printf("%s / %s\n", dirPathBuf, items[i]->d_name);

        addSrc(&srcNodeHead, &srcNodeTail, dirPathBuf, items[i]->d_name);
        
        lstat(items[i]->d_name, &fstat);
        
        if((fstat.st_mode & S_IFDIR) == S_IFDIR){
            if(indent<(depth-1) || (depth==0)){
                indent++;
                scanDir(items[i]->d_name, func, depth);
                
            }
        }
    }
    
    indent--;
    chdir("..");
    
}


// existResHead 에 refResHead 가 있는지 확인
//
// 없으면 없는 갯수를 리턴.
// 성공 0 리턴.

int checkResource(RES_NODE *refResHead, RES_NODE *existResHead){
    
    printf("\n< Resource Check start >\n");
    
    int noResourceCnt = 0;
    BOOL isExist;
    char refResNameBuf[256];
    RES_NODE *existResStartNode = existResHead;
    
    while ( refResHead != NULL ) {
        
        isExist = FALSE;
         
        memset(refResNameBuf, '\0', 256);
        sprintf(refResNameBuf, "%s.%s", refResHead->name, "png");
        printf("%s\n", refResNameBuf);
        
        while (existResHead != NULL) {
            
//          printf("Compare : %s - %s\n", refResNameBuf, existResHead->name);
            
            if (strcmp(refResNameBuf, existResHead->name) == 0) {
                isExist = TRUE;
                break;
            }
            
            existResHead = existResHead->next;
            
        }
        
        if(isExist == FALSE){
            noResourceCnt++;
        }
        
        refResHead = refResHead->next;
        existResHead = existResStartNode;
        
    }
    
    printf("- Resource Check end -\n");
    
    return noResourceCnt;
        
}

