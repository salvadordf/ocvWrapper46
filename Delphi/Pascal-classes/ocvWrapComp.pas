{
  Non-visual VCL/LCL components for OpencvWrapper46 .

  Copyright (C) 2023 Giandomenico De Sanctis gidesay@yahoo.com

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
  Boston, MA 02110-1335, USA.
}


unit ocvWrapComp;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF LCL}
  LCLIntf, LCLType, LResources,
  ExtCtrls,  Forms,
  SyncObjs,  lazCollections, Generics.Collections,
  {$IFDEF UNIX}
  {$IFDEF UseCThreads}cthreads,{$ENDIF}
  {$ENDIF}
  {$ELSE}
  Messages,  Vcl.ExtCtrls,  Vcl.Forms,
  System.SyncObjs,  System.Generics.Collections,
  {$ENDIF}
  SysUtils, Classes,
  OPENCVWrapper,  unOpenCVDelphi46, unOCVImage, CommThread;
Type

  TVideoSourceType = (vsCamera, vsFile);


  TOnErrorEvent = procedure(Sender: TObject; errorMess: string) of object;
  TOnFrameEvent =  procedure(Sender: TObject; const frame: TOCVImage) of object;

  //** Class that encapsulates properties of video camera source
  TOcvCameraProp = class(TPersistent)
  private
    fHeight: Integer;
    fWidth: Integer;
    fBrightness: Integer;
    fContrast: Integer;
    fGamma: Integer;
    fFPS: Integer;
    fWhiteBalance: Integer;
    FAutoWhiteBalance: Boolean;
  published
    property Height: Integer read FHeight write FHeight;
    property Width: Integer read FWidth write FWidth;
    property Brightness: Integer read FBrightness write FBrightness;
    property Contrast: Integer read FContrast write FContrast;
    property Gamma: Integer read FGamma write FGamma;
    property FPS: Integer read FFPS write FFPS;
    property WhiteBalance: Integer read FWhiteBalance write FWhiteBalance;
    property AutoWhiteBalance: Boolean read FAutoWhiteBalance write FAutoWhiteBalance;
  end;

  TOcvProcessor = class;

  //** This is the base class of  sources of images that are feeded into Opencv processors.
  TOcvImageSource = class(TComponent)
  private
    fImage: TImage;
    fActive: Boolean;

    fOnFrame: TOnFrameEvent;

    frame:   PCvMat_t;
    ocvframe: TOCVImage;
    processorComps: TList<TOcvProcessor>;

    simEv:    TSimpleEvent;
    th:       TThread;
  {$IFDEF FPC}
    tt:       integer;
    procedure capture();
  {$ENDIF}
  protected
    procedure setActive(val: Boolean); virtual;
    procedure StartCapture(const ShutdownEvent: TSimpleEvent; const ocvVidCap: TOcvImageSource); virtual;
    procedure activate();   virtual;
    procedure deActivate(); virtual;
    procedure readFrame();  virtual;
    procedure readError();  virtual;
    procedure endRead();    virtual;
    procedure connectProcessors();
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(owner: TComponent); override;
    procedure BeforeDestruction; override;
    //** Activate or deactivate the stream from the images source
     property Active: Boolean read fActive write setActive;
  published
     //** A TImage component where to show image from source
     property DisplayImage: TImage read fImage write fImage;
     //** Event fired when an image is acquired from source
     property OnFrame: TOnFrameEvent read fOnFrame write fOnFrame;
  end;

  //** Component for video  as source of images/frames. Can use a realtime video stream, or a video file.
  TOcvVideoCapture = class(TOcvImageSource)
  private
    { Private declarations }
    fFilename: TFileName;
    fVideosource: Integer;
    fVideosourceType: TVideoSourceType;
    fCameraProp: TOcvCameraProp;

    capture: PCvVideoCapture_t;

    procedure setCameraProp();
    procedure setVideosource(val: TVideoSourceType);
    procedure activate();   override;
    procedure deActivate(); override;
    procedure readFrame();  override;
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(owner: TComponent); override;
    procedure BeforeDestruction; override;
  published
    { Published declarations }
     //** Activate or deactivate the stream from the images source
     property Active: Boolean read fActive write setActive;
     //** Video source type: video stream from camera, or video file
     property VideoSourceType: TVideoSourceType read fVideosourceType write setVideosource;
     //** Video file name
     property VideoFileName: TFileName read fFilename write fFilename;
     //** Video source for stream, it's the numeric id of system video source
     property VideoSource: Integer read fVideosource write fVideosource;
     //** Properties to get/set from/to video camera
     property CameraProp: TOcvCameraProp read FCameraProp write FCameraProp;
  end;

 //** Component for using a file system directory  as source of images.
 TOcvImageDirectory = class(TOcvImageSource)
  private
    { Private declarations }
    fDirecname: TFileName;
    fExt: string;
    fSlidePause: Integer;

    sr: TSearchRec;
    searchWild: string;

    pnprogr: Integer;
    filename: string;

    procedure activate();   override;
    procedure deActivate(); override;
    procedure readFrame();  override;
    procedure cycleDirec();
    procedure setDirecName(val: TFileName);
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(owner: TComponent); override;
  published
    { Published declarations }
    //** Image files directory name
    property DirectoryName: TFileName read FDirecName write setDirecName;
    //** Image files extensions list, default BMP, PNG, JPG
    property Ext: string read FExt write FExt;
    //** Pause in milliseconds between read of files, default 30
    property SlidePause: integer read FSlidePause write FSlidePause;
  end;

  TODThreadProcessError = procedure(errMess: string) of object;

  //** Thread class for object detection. Used in queue of requests
  TObjDetThread = class(TCommThread<TOCVImage,TDetection>)
  private
     objdet: IDNNDetection;
     detections: TDetectionList;
     img: TOCVImage;

     fProcessing: Boolean;
     fErrorMess: string;
     fProcessError: TODThreadProcessError;

     procedure signalError(ms: string);
  protected
     procedure ProcessMessage(const data: TOCVImage); override;
  public
     constructor Create(qWorkers: TMessageQueue<TOCVImage>;
                qMain: TMessageQueue<TDetection>;
                const objectDetector: IDNNDetection;
                const processError: TODThreadProcessError = nil);
     destructor  Destroy; override;

     property ErrorMess: string read FErrorMess ;
     property Processing: boolean read FProcessing write FProcessing;

  end;

  //** Base class for Opencv image processor components
  TOcvProcessor = class(TComponent)
  private
    fImage: TImage;
    fOcvCap: TOcvImageSource;
    fThreadNum: Integer;
    fActive: Boolean;
    fImagesBufferLength: Integer;

    fOnError: TOnErrorEvent;

    internOcvimg: TOCVImage;
    detections: TDetectionList;

    procThreads: TArray<TObjDetThread>;
    bufImages: TArray<TOCVImage>;
    curBufInd: Integer;
    curDetectImageId: Integer;
    curDetection: TDetection;

  protected
    isProcessing: Boolean;
    procedure processError(errMess: string); virtual;
    procedure display(const ocvimg: TOCVImage; const drawBackground: Boolean); virtual; abstract;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure activate(); virtual;
    procedure deactivate(); virtual;
    procedure deactivateThreads(); virtual;
    procedure initBuffer(const img: TOCVImage);
    procedure setActive(val: Boolean); virtual;
    procedure setThreadNum(val: Integer);
  public
    constructor Create(owner: TComponent); override;
    procedure BeforeDestruction; override;

    procedure process(const img: TOCVImage); virtual;
    procedure endProcess();   virtual;
    property Active: boolean read FActive write SetActive;
    //** Number of separate thread used to process images
    property ThreadNum: Integer read FThreadNum write setThreadNum;
  published
     //** A TImage component where to show image from source
     property DisplayImage: TImage read fImage write fImage;
     //** A TOcvImageSource component that feeds the images
     property VideoCapture:  TOcvImageSource read fOcvCap write fOcvCap;
     //** Length of internal buffer for images, default 20. More is length, better is processing of fast stream,
     //** but greater is memory used
     property ImagesBufferLength: Integer read FImagesBufferLength write FImagesBufferLength;
     //** Event fired when there is an error in processing image
     property OnError: TOnErrorEvent read fOnError write fOnError;
 end;

  TOnImageProcessed = procedure(Sender: TObject; const frame: TOCVImage; const detections: TDetectionList) of object;

  //** Component for object detection in an image/frame
  TOcvProcObjectDetector = class(TOcvProcessor)
  private
    fModelBinName: TFileName;
    fModelConfigName: TFileName;
    fModelClassesName: TFileName;
    fThreshold: Single;

    fQueueToWorkers: TMessageQueue<TOcvImage>;
    fQueueToMain:    TMessageQueue<TDetection>;

    fOnImageProcessed: TOnImageProcessed;

    objdet: array of TOcvDNNObjDetect;

    procedure activate(); override;
    procedure deactivate(); override;
    procedure display(const ocvimg: TOCVImage; const drawBackground: Boolean);  override;
    procedure getResult();
    procedure processResult(const detResult: TDetection);
  protected
  public
    constructor Create(owner: TComponent); override;
    procedure process(const img: TOCVImage);  override;

  published
     //** File name of the neural network binary model
     property ModelBinName: TFileName read FModelBinName write FModelBinName;
     //** File name of model configuration file
     property ModelConfigName: TFileName read FModelConfigName write FModelConfigName;
     //** File name of the list containing the classes (categories) names
     property ModelClassesName: TFileName read FModelClassesName write FModelClassesName;
     //** Minimum value between 0 and 1 for accepting the detection. Only detections with not less confidence
     //** (quality) will be returned
     property Threshold: single read FThreshold write FThreshold;

     //** Event fired when the processing of single image/frame is terminated
     property OnObjDetProcessed: TOnImageProcessed  read  fOnImageProcessed write fOnImageProcessed;
  end;

  //** Component for human face detection in an image/frame
  TOcvProcFaceDetector = class(TOcvProcessor)
  private
    fModelBinName: TFileName;
    fModelConfigName: TFileName;
    fScoreThreshold: Single;
    fNmsThreshold: Single;
    fTopK: Integer;

    fRecognize:             Boolean;
    fReconModelBinName:     TFileName;
    fReconModelConfigName:  TFileName;
    fReconFacesNames:       TFileName;
    fReconFeaturesName:     TFileName;

    fQueueToWorkers: TMessageQueue<TOcvImage>;
    fQueueToMain:    TMessageQueue<TDetection>;

    fOnImageProcessed: TOnImageProcessed;

    objdet: TArray<TOcvDNNFaceDetect>;

    procedure activate(); override;
    procedure deactivate(); override;
    procedure display(const ocvimg: TOCVImage; const drawBackground: Boolean);  override;
    procedure getResult();
    procedure processResult(const detResult: TDetection);
  protected
  public
    constructor Create(owner: TComponent); override;

    procedure process(const img: TOCVImage);  override;

  published
     //** File name of the neural network binary model
     property ModelBinName: TFileName read FModelBinName write FModelBinName;
     //** File name of model configuration file
     property ModelConfigName: TFileName read FModelConfigName write FModelConfigName;
     //** Threshold on the detection confidence: only face detections with confidence >= threshold
     // are returned. Default 0.9
     property ScoreThreshold: Single read FScoreThreshold write FScoreThreshold;
     //** Non Maxima Suppression (NMS) threshold used internally. Default 0.3
     property NmsThreshold: Single read FNmsThreshold write FNmsThreshold;
     //**  The number of bounding boxes preserved before NMS. Default  5000
     property TopK: Integer read FTopK write FTopK;
     //** Length of internal buffer for images, default 20. More is length, better is processing of fast stream,
     //** but greater is memory used
     property ImagesBufferLength: Integer read FImagesBufferLength write FImagesBufferLength;
     //** Set recognize = true if you want to activate face recognition
     property Recognize: boolean read FRecognize write FRecognize;
     //** Name of face recognition binary model file
     property ReconModelBinName: TFileName read FReconModelBinName write FReconModelBinName;
     //** Name of face recognition model configuration file, optional. Depend from model binary type used
     property ReconModelConfigName: TFileName read FReconModelConfigName write FReconModelConfigName;
     //** Name of face recognition file that contains assignment of a name to face training images
     property ReconFacesNames: TFileName read FReconFacesNames write FReconFacesNames;
     //** Name of face recognition JSON file that bind a feature array to every face name
     property ReconFeaturesName: TFileName read FReconFeaturesName write FReconFeaturesName;

     //** Event fired when the processing of single image/frame is terminated
     property OnObjDetProcessed: TOnImageProcessed  read  fOnImageProcessed write fOnImageProcessed;
  end;

  TVideoCodec = (vcMP43,vcDIVX,vcMJPG,vcMPEG,vcXVID, vcX264, vcWMV1, vcI420, vcIYUV, vcFFV1, vcHFYU);
  TOnFrameWrite = procedure(Sender: TObject; const frame: TOCVImage) of object;

  //** Component to write a movie from image source
  TOcvProcMovieWrite = class(TOcvProcessor)
  private
    fFilename   : string;
    fFourccCodec: TVideoCodec;
    fFps        : Integer;
    fFrameWidth : Integer;
    fFrameHeight: Integer;

    ocvwriter   : PCvVideoWriter_t;

    fOnFrameWrite: TOnFrameWrite;


    procedure activate(); override;
    procedure deactivate(); override;
    procedure display(const ocvimg: TOCVImage; const drawBackground: Boolean);  override;

    procedure SetFourccCodec(val: TVideoCodec);
    procedure SetFps(val: Integer);

    //** Only one thread used to process images
    property ThreadNum: Integer read FThreadNum write setThreadNum;

  protected
  public
    class procedure GetVideoCodecList(codecNames: TStrings);
    constructor Create(owner: TComponent); override;
    procedure process(const img: TOCVImage);  override;

  published
     //** File name of saved movie
     property FileName: string read fFilename write fFilename;
     //** Codec used in saved file, as a fourcc 4 characters code
     property fourccCodec: TVideoCodec read FfourccCodec write SetfourccCodec;
     //** Frame per second of saved movie
     property Fps: integer read FFps write SetFps;
     //** Width of movie frame
     property frameWidth: Integer read FframeWidth write FframeWidth;
     //** Height of movie frame
     property frameHeight: Integer read FframeHeight write FframeHeight;

     //** Event fired when the processing of single image/frame is terminated
     property OnFrameWrite: TOnFrameWrite  read  fOnFrameWrite write fOnFrameWrite;
  end;


procedure Register;
{-----------------------------------------------------------------------------}
implementation

uses
 {$IFDEF LCL}
  Graphics, Typinfo;
 {$ELSE}
  Vcl.Graphics, System.TypInfo;
 {$ENDIF}


{----- error management -----}
const
erActivateSource = 1000;
erNoFilename     = 1001;
erNotOpen        = 1002;
erRead           = 1003;

erObjDetFilename = 1004;
erProcess        = 1005;
erProcessThread  = 1006;


type
  EOcvVCError = class(Exception);


var
  errMess: string;
  nrErr:   Integer = 0;


procedure RaiseError(routerr: integer; strMessage: String);
begin
    Raise EOcvVCError.create('['+inttostr(routerr)+']: ' + strMessage);
End;
{----------------------------}

procedure Register;
begin
  RegisterComponents('Opencv', [TOcvVideoCapture, TOcvImageDirectory, TOcvProcObjectDetector, TOcvProcFaceDetector,
                         TOcvProcMovieWrite]);
end;


{******************************************************************************}
{******************** TOcvImageSource *****************************************}
{******************************************************************************}
{$REGION 'TOcvImageSource'}

constructor TOcvImageSource.Create(owner: TComponent);
begin
    inherited create(owner);
    fActive:=False;
    fImage:=nil;
    th:=nil;
    ocvframe:=nil;
    frame:=pCvMatCreateEmpty();
end;

procedure TOcvImageSource.beforeDestruction();
begin
    inherited BeforeDestruction;
    if fActive= True then
    begin
         setActive(false);
    end;
    if Assigned(th) then
    begin
        try
           // setting freeOnTerminate is important to properly free the video loop thread
          th.FreeOnTerminate:=False;
          th.Terminate;
          th.WaitFor;
          th.Free;
        except
          // nop
        end;
    end;

    if Assigned(simEv) then
      FreeAndNil(simEv);
end;

procedure TOcvImageSource.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = fImage) and (Operation = opRemove) then
    fImage:=nil;
end;

{$IFDEF FPC}
procedure TOcvImageSource.capture();
var
    waitResult: TWaitResult;
begin
    errMess:='';
    repeat
      if not Assigned(simEv) then
        break;

      // execute the loop for image capture/processing
      try
        tthread.Synchronize(TThread.CurrentThread, self.readFrame);
      except
        on E: Exception do
        begin
            errMess := e.Message;
            tthread.Synchronize(TThread.CurrentThread, self.readError);
            break;
        end;
      end;


      waitResult:=wrTimeout;
      waitResult := simEv.WaitFor(tt);
      // if result = wrTimeout, then -> no other events during tt milliseconds
      if (TThread.CheckTerminated = true) or  (waitResult <> wrTimeOut) then
      begin
          // other result -> the exit event was fired
          tthread.Synchronize(TThread.CurrentThread, self.endRead);
          break;  // from repeat loop
      end;
    until  (TThread.CheckTerminated = true) or (simEv.WaitFor(1) <> wrTimeout);

end;
{$ENDIF}



procedure  TOcvImageSource.StartCapture(const ShutdownEvent: TSimpleEvent;
                                    const ocvVidCap: TOcvImageSource);
{$IFNDEF FPC}
var
  tt: Integer;
{$ENDIF}
begin
  tt:= 30;
{$IFDEF FPC}
  th := TThread.ExecuteInThread(capture, nil);
{$ELSE}
  th := TThread.CreateAnonymousThread(
    procedure
    var
      waitResult: TWaitResult;
    begin
      errMess:='';
      repeat
        if not Assigned(ShutdownEvent) then
          break;

        // execute the loop for image capture/processing
        try
          tthread.Synchronize(TThread.CurrentThread, ocvVidCap.readFrame);
        except
          on E: Exception do
          begin
              errMess := e.Message;
              tthread.Synchronize(TThread.CurrentThread, ocvVidCap.readError);
              break;
          end;
        end;


        waitResult:=wrTimeout;
        waitResult := ShutdownEvent.WaitFor(tt);
        // if result = wrTimeout, then -> no other events during tt milliseconds
        if (TThread.CheckTerminated = true) or  (waitResult <> wrTimeOut) then
        begin
            // other result -> the exit event was fired
            tthread.Synchronize(TThread.CurrentThread, ocvVidCap.endRead);
            break;  // from repeat loop
        end;
      until  (TThread.CheckTerminated = true) or (ShutdownEvent.WaitFor(1) <> wrTimeout);

    end
  );
{$ENDIF}
  th.Start;
end;


procedure TOcvImageSource.connectProcessors;
var
  i, nc: Integer;
  dproc: TOcvProcessor;
begin
  processorComps:=TList<TOcvProcessor>.Create;
  nc:=Owner.ComponentCount;
  for i:=0 to nc-1 do
  begin
    if Owner.Components[i] is TOcvProcessor then
    begin
      dproc:= TOcvProcessor(Owner.Components[i]);
      if dproc.VideoCapture = self then
         processorComps.Add(dproc);
    end;
  end;
end;

procedure TOcvImageSource.activate;
begin
    connectProcessors;
end;


procedure TOcvImageSource.deActivate;
begin
  if Assigned(processorComps) then
      processorComps.Free;
end;

procedure TOcvImageSource.setActive(val: Boolean);
begin
  if fActive=val then Exit;
  case fActive of
  True:  begin   // val is false
     deActivate;
     fActive:=False;
  end;
  False: begin  // val is true
     activate;
     fActive:=True;
     end;
  end;
end;

procedure TOcvImageSource.readFrame;
begin
  //nop
end;

procedure TOcvImageSource.endRead;
begin
   if fActive=True then
      setActive(false);
end;

procedure TOcvImageSource.readError();
begin
  RaiseError(erRead, errMess);
end;

{$ENDREGION}

{******************************************************************************}
{******************** TOcvVideoCapture ****************************************}
{******************************************************************************}

{$REGION 'TOcvVideoCapture'}

constructor TOcvVideoCapture.Create(owner: TComponent);
begin
    inherited create(owner);
    fFilename:='';
    fVideosource:=0;
    fCameraProp:=TOcvCameraProp.Create();
    with fCameraProp do
    begin
       Width:=640;
       Height:=480;
       Brightness:=100;
       Contrast:=5;
       FPS:=15;
       Gamma:=100;
       WhiteBalance:=4500;
    end;
    capture:=nil;
end;

procedure TOcvVideoCapture.beforeDestruction();
begin
    inherited BeforeDestruction;
    CameraProp.Free;
end;



procedure TOcvVideoCapture.setCameraProp;
var
  res: Boolean;
begin
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_FPS), CameraProp.FPS);
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_FRAME_WIDTH), CameraProp.Width);
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_FRAME_HEIGHT), CameraProp.Height);
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_BRIGHTNESS), CameraProp.Brightness );
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_CONTRAST), CameraProp.Contrast );
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_GAMMA), CameraProp.Gamma );
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_AUTO_WB), Integer(CameraProp.AutoWhiteBalance) );
   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_WB_TEMPERATURE), CameraProp.WhiteBalance );
//   res:=pCvVideoCaptureset(capture, Ord(CAP_PROP_), CameraProp. );

   { Refresh properties with values really accepted by camera driver }
   CameraProp.Width :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_FRAME_WIDTH)));
   CameraProp.Height :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_FRAME_HEIGHT)));
   CameraProp.FPS :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_FPS)));
   CameraProp.Brightness :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_BRIGHTNESS)));
   CameraProp.Contrast :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_CONTRAST)));
   CameraProp.WhiteBalance :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_WB_TEMPERATURE)));
   CameraProp.AutoWhiteBalance := Boolean(Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_AUTO_WB))));
   CameraProp.Gamma :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_GAMMA)));
//   CameraProp. :=Round(pCvVideoCaptureget(capture, Ord(CAP_PROP_)));
end;

procedure TOcvVideoCapture.activate;
var
  cvstr: CvString_t;
  apiPreference: Integer;
begin
   connectProcessors;

   capture:=pCvVideoCaptureCreate();
   if fVideosourceType = vsCamera then
      try
         {$IFDEF MSWINDOWS}
         apiPreference:=Ord(CAP_DSHOW);
         {$ELSE}
         apiPreference:=ord(CAP_ANY);
         {$ENDIF}
         pCvVideoCaptureopenV3(capture, fVideosource, apiPreference);
         setCameraProp;
      except
        on E: Exception do
            RaiseError(erActivateSource,'Error: '+E.Message);
      end;
   if fVideosourceType = vsFile then
   begin
       if fFilename = '' then
          RaiseError(erNoFilename, 'Error: file name is empty');
       cvstr.pstr:=PAnsiChar(AnsiString(fFilename));
       try
          pCvVideoCaptureopen(capture, @cvstr);
       except
        on E: Exception do
            RaiseError(erActivateSource,'Error: '+E.Message);
      end;
   end;
    if not(pCvVideoCaptureisOpened(capture)) then
        RaiseError(erNotOpen, 'Error: video capture not opened');
    if Assigned(simEv) then
      FreeAndNil(simEv);
    {$IFDEF FPC}
    simEv := TSimpleEvent.Create();
    {$ELSE}
    simEv := TSimpleEvent.Create(Nil,False,False,'');
    {$ENDIF}
    if frame = nil then
      frame:=pCvMatCreateEmpty();

    StartCapture(simEv, self);

end;

procedure TOcvVideoCapture.deActivate;
begin
   if Assigned(simEv) then
   begin
      simEv.SetEvent;
   end;
   if capture<>nil then
   begin
      pCvVideoCapturerelease(capture);
      pCvVideoCaptureDelete(capture);
      capture:=nil;
   end;
   FreeAndNil(ocvframe);
   frame:=nil;
   if Assigned(processorComps) then
     FreeAndNil(processorComps);

end;



procedure TOcvVideoCapture.setVideosource(val: TVideoSourceType);
begin
  if fVideosourceType <> val then
  begin
      setActive(false);
      fVideosourceType := val;
  end;
end;


procedure TOcvVideoCapture.readFrame;
var
  dproc: TOcvProcessor;
begin
  if fImage<>nil then
      fImage.FreeNotification(self);
  if capture = nil then Exit;
  if not(pCvVideoCaptureread(capture, frame)) then
  begin
     if Assigned(simEv) then
        simEv.SetEvent;
     Exit;
  end;
  try
    if ocvframe=nil then
       ocvframe:=TOCVImage.Create(frame);
    if Assigned(fOnFrame) then
        fOnFrame(Self, ocvframe);
    if fImage<>nil then
       ocvframe.showInImage(fImage);
    Application.ProcessMessages;

    if Assigned(processorComps) then
        for dproc in processorComps do
        begin
            dproc.process(ocvframe);
        end;
  except
    on E: Exception do
    begin
     if Assigned(simEv) then
        simEv.SetEvent;
     RaiseError(erProcess, E.Message);
     setActive(False);
    end;
  end;

end;


{$ENDREGION}

{******************************************************************************}
{******************** TOcvImageDirectory **************************************}
{******************************************************************************}

{$REGION 'TOcvImageDirectory'}

constructor TOcvImageDirectory.Create(owner: TComponent);
begin
   inherited Create(owner);
   fDirecname:='';
   searchWild:='*';
   fExt := '.BMP;.JPG;.PNG';
   fSlidePause:=30;
end;

procedure TOcvImageDirectory.setDirecName(val: TFileName);
var
  direc: string;
begin
  direc:=ExtractFilePath(val);
  if (direc = '') or (DirectoryExists(direc) and  (direc<>fDirecname)) then
    fDirecname:=direc;
end;


procedure TOcvImageDirectory.activate;
begin
  if (csDesigning in ComponentState) then  Exit;
  if fDirecname = '' then
          RaiseError(erNoFilename, 'Error: directory name is empty');

  connectProcessors;
  pnprogr := 0;
  filename:='';
  if FindFirst(fDirecname+searchWild, faAnyFile, sr) = 0 then
  begin
    if Assigned(simEv) then
      FreeAndNil(simEv);
    {$IFDEF FPC}
    simEv := TSimpleEvent.Create();
    {$ELSE}
    simEv := TSimpleEvent.Create(Nil,False,False,'');
    {$ENDIF}
    StartCapture(simEv, self);
  end;
end;

procedure TOcvImageDirectory.deActivate;
begin
  inherited deActivate;
  if Assigned(simEv) then
      simEv.SetEvent;
  FindClose(sr);
  if Assigned(ocvframe) then
    FreeAndNil(ocvframe);
end;

procedure TOcvImageDirectory.cycleDirec;
var
  fn : string;
begin
    filename:='';
    repeat
      begin
        fn := sr.Name;
        if (fn <> '.') and (fn <> '..') then
           if (fExt='') or (Pos(UpperCase(ExtractFileExt(fn)), fExt)>0) then
              begin
                Inc(pnprogr);
                filename:=fDirecname+fn;
                Break;
              end;
     end;
    until FindNext(sr) <> 0;
end;



procedure TOcvImageDirectory.readFrame;
var
   waitResult: TWaitResult;
   dproc: TOcvProcessor;
begin
  if not(fActive) then Exit;

  if fImage<>nil then
      fImage.FreeNotification(self);

  cycleDirec;
  if filename='' then
  begin
      if Assigned(simEv) then
          simEv.SetEvent;
      Exit;
  end;
  if ocvframe=nil then
    ocvframe:=TOCVImage.Create(100,100,3);

  try
    ocvframe.load(filename);
    ocvframe.ID:=pnprogr;
    if Assigned(fOnFrame) then
        fOnFrame(Self, ocvframe);
    if fImage<>nil then
       ocvframe.showInImage(fImage);

    if Assigned(processorComps) then
        for dproc in processorComps do
        begin
            dproc.process(ocvframe);
        end;
    Application.ProcessMessages;
//    FreeAndNil(ocvframe);
    waitResult:=wrTimeout;
    // wait for slide pause milliseconds in non blocking mode
    waitResult := simEv.WaitFor(fSlidePause);

    // no more files
    if FindNext(sr) <> 0 then
      if Assigned(simEv) then
          simEv.SetEvent;

  except
    on E: Exception do
    begin
     if Assigned(simEv) then
        simEv.SetEvent;
     RaiseError(erProcess, E.Message);
     setActive(False);
    end;
  end;
end;

{$ENDREGION}

{******************************************************************************}
{******************** TOcvProcessor *******************************************}
{******************************************************************************}

{$REGION 'TOcvProcessor'}
constructor TOcvProcessor.Create(owner: TComponent);
begin
  inherited;
  fImage:=nil;
  fOcvCap:=nil;
  isProcessing:=False;
  fActive:=False;
  fThreadNum:=1;
  detections:=TDetectionList.Create;
  SetLength(procThreads, fThreadNum);
  procThreads[0]:=nil;
  SetLength(bufImages, 0);
  fImagesBufferLength:=20;

  fOnError:=nil;
end;

procedure TOcvProcessor.BeforeDestruction;
var
  img: TObject;
begin
  inherited BeforeDestruction;
  if fActive=True then
      deactivate;
  detections.Free;
  for img in bufImages do
    img.Free;
end;

procedure TOcvProcessor.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = fImage) and (Operation = opRemove) then
    fImage:=nil;
  if (AComponent = fOcvCap) and (Operation = opRemove) then
    fOcvCap:=nil;
end;


procedure TOcvProcessor.initBuffer(const img: TOCVImage);
var
  i: Integer;
begin
  SetLength(bufImages, fImagesBufferLength);
  curBufInd:=0;
  for I:=Low(bufImages) to High(bufImages) do
  begin
    bufImages[i]:=TOCVImage.Create(img.width, img.height, img.nchannels);
    bufImages[i].ID:=i;
  end;
end;



procedure TOcvProcessor.activate;
begin
  if (csDesigning in ComponentState) then  Exit;

  curBufInd:=0;
  curDetectImageId:=-1;

  isProcessing:=True;
end;


procedure TOcvProcessor.deactivate;
begin
  isProcessing:=False;
end;

procedure TOcvProcessor.deactivateThreads;
var
  i: Integer;
  dt: TDetection;
begin
  if Assigned(procThreads[0]) then
  begin
    for i:=Low(procThreads) to High(procThreads) do
    begin
     if Assigned(procThreads[i]) then
     begin
       try
         procThreads[i].Terminate;
         while procThreads[i].Processing do
            Sleep(10);
         FreeAndNil(procThreads[i]);
       except
         // nop
       end;
     end;
     // objdet[xx] are interfaced objects, so with automatic release
    end;
  end;
  for dt in detections do
  begin
   try
      dt.Free;
   except
      // invalid pointer: object was destroyed before
   end;
  end;
  detections.Clear;
  if Assigned(curDetection) then
    curDetection.Free;
end;


procedure TOcvProcessor.setActive(val: Boolean);
begin
  if fActive=val then Exit;
  case fActive of
  True: begin   // val is false
    deactivate;
  end;
  False: begin  // val is true
    activate;
  end;
  end;
  fActive:=val;
end;


procedure TOcvProcessor.setThreadNum(val: Integer);
begin
  if (val>0) and (val <= 10) then
    fThreadNum:=val;
end;


procedure TOcvProcessor.process(const img: TOCVImage);
begin
  //nop
end;


procedure TOcvProcessor.processError(errMess: string);
begin
  if (errMess<>'') and Assigned(fOnError) then
  begin
      fOnError(self, IntToStr(erProcess)+ ' <'+ClassName+ '> ['+ errMess+']');
  end;
end;


procedure TOcvProcessor.endProcess;
begin
  isProcessing:=False;
end;
{$ENDREGION}

{******************************************************************************}
{******************** TObjDetThread *******************************************}
{******************************************************************************}

{$REGION 'TOBjDetThread'}
constructor TObjDetThread.Create(qWorkers: TMessageQueue<TOCVImage>;
      qMain: TMessageQueue<TDetection>;
      const objectDetector: IDNNDetection;
      const processError: TODThreadProcessError);
begin
   inherited Create(qWorkers, qMain);
   objdet:=objectDetector;
   detections:=TDetectionList.Create;
   fprocessing:=False;
   img:=nil;
   fErrorMess:='';
   fProcessError:=processError;
end;


destructor TObjDetThread.Destroy;
begin
  if Assigned(detections) then
  begin
      detections.Clear;
      detections.Free;
  end;
  img.Free;
  inherited;
end;

procedure TObjDetThread.signalError(ms: string);
begin
  fErrorMess:=ms;
  fProcessing:=False;
  // Error messages not supported as of FPC 3.2.2 without anonymous methods
  {$IFNDEF FPC}
  if Assigned(fProcessError) then
    TThread.Synchronize(self, procedure
                              begin
                                  fProcessError(fErrorMess);
                              end);
  {$ENDIF}
end;

 procedure TObjDetThread.ProcessMessage(const data: TOCVImage);
 var
  dt: TDetection;
 begin
  if (Terminated=True) or  (data=nil) then Exit;
  try
    fProcessing:=True;
    if (img=nil) or (img.width <> data.width)
         or (img.height <> data.height) then
    begin
      if Assigned(img) then
        FreeAndNil(img);
      img:=data.clone();
    end else
      data.copy(img);
    img.ID:=data.ID;
    objdet.process(img, detections);
    if detections.Count>0 then
        for dt in detections do
        begin
          if not SendToMain(dt) then
          begin
             dt.Free;
          end;
        end
    else
        begin
          // no detection
          dt:=TDetection.Create;
          dt.imageId:=data.ID;
          dt.classId:=-1;
          if not SendToMain(dt) then
               dt.Free;
        end;

    fProcessing:=False;
  except
    on E: Exception do
    begin
       signalError(E.Message);
    end;
  end;

end;

 {$ENDREGION}
{******************************************************************************}
{******************** TOcvProcObjectDetector **********************************}
{******************************************************************************}

{$REGION 'TOcvProcObjectDetector'}
constructor TOcvProcObjectDetector.Create(owner: TComponent);
begin
  inherited;
  fThreshold:=0.7;
  fModelBinName:='';
  fModelConfigName:='';
  fModelClassesName:='';
  fQueueToMain:=nil;
  fQueueToWorkers:=nil;
  SetLength(objdet, fThreadNum);
end;


procedure TOcvProcObjectDetector.activate;
var
  i: Integer;
begin
  inherited activate;

  if (fModelBinName='') or (fModelConfigName='') or (fModelClassesName='') then
  begin
    RaiseError(erObjDetFilename,'Error: model file name for binary data, configs, and classes, must be set');
  end;

  fQueueToMain:=TMessageQueue<TDetection>.Create(500, getResult);
  fQueueToWorkers:=TMessageQueue<TOCVImage>.Create(500, nil);

  SetLength(procThreads, 0);
  SetLength(objdet, 0);
  SetLength(procThreads, fThreadNum);
  SetLength(objdet, fThreadNum);
  for i:=Low(procThreads) to High(procThreads) do
  begin
      objdet[i]:=TOcvDNNObjDetect.Create(fModelBinName, fModelConfigName, fModelClassesName);
      objdet[i].threshold:=fThreshold;
      procThreads[i]:=TObjDetThread.Create(fQueueToWorkers, fQueueToMain, objdet[i], processError);
  end;
end;

procedure TOcvProcObjectDetector.deactivate;
begin
  isProcessing:=False;
  inherited deactivateThreads;

  if Assigned(fQueueToWorkers) then
  begin
       fQueueToWorkers.Shutdown;
       Sleep(100);
       FreeAndNil(fQueueToWorkers);
  end;
  if Assigned(fQueueToMain) then
  begin
       fQueueToMain.Shutdown;
       Sleep(100);
       FreeAndNil(fQueueToMain);
  end;
end;



procedure TOcvProcObjectDetector.process(const img: TOCVImage);
begin
  if not(isProcessing) then Exit;
  if Length(bufImages) = 0 then
    initBuffer(img);
  if (img.width = bufImages[curBufInd].width) and
     (img.height = bufImages[curBufInd].height) then
        img.copy(bufImages[curBufInd])
  else begin
    FreeAndNil(bufImages[curBufInd]);
    bufImages[curBufInd]:=img.clone();
    bufImages[curBufInd].ID:=curBufInd;
  end;

  if not(fQueueToWorkers.Send(bufImages[curBufInd])) then
     Inc(nrErr);
  Inc(curBufInd);
  if curBufInd>High(bufImages) then
    curBufInd:=Low(bufImages);
end;

procedure TOcvProcObjectDetector.getResult;
var
  dt: TDetection;
begin
  if Assigned(fQueueToMain) then
  begin
     dt:=nil;
     dt:=fQueueToMain.popValue();
     if Assigned(dt) then
         processResult(dt);
  end;
end;


procedure TOcvProcObjectDetector.processResult(const detResult: TDetection);
var
  dt: TDetection;
  drawBackground: Boolean;
begin
  if not(isProcessing) then
  begin
     detResult.Free;
     Exit;
  end;

  drawBackground:=False;
  if detResult.imageId <> curDetectImageId then
  begin
      if Assigned(fOnImageProcessed) then
      begin
        internOcvimg:=bufImages[curDetectImageId];
        fOnImageProcessed(Self, internOcvimg, detections);
      end;
      for dt in detections do
        dt.Free;
      detections.Clear;
      curDetectImageId:=detResult.imageId;
      drawBackground:=True
  end;


  curDetection:=detResult;
  detections.Add(detResult);
  internOcvimg:=bufImages[curDetectImageId];
  if Assigned(fImage) then
         display(internOcvimg, drawBackground);
  curDetection:=nil;

end;


procedure TOcvProcObjectDetector.display(const ocvimg: TOCVImage; const drawBackground: Boolean);
var
  scaleX, scaleY: Single;
  bmp: TBitmap;
begin
  if drawBackground then
     ocvimg.showInImage(fImage);
  bmp:=fImage.Picture.Bitmap;
  scaleX:= bmp.Width / ocvimg.width;
  scaleY := bmp.Height / ocvimg.height;
  curDetection.draw(bmp, scaleX, scaleY);
//OutputDebugString(PWideChar('imgId ' + IntToStr(curDetectImageId)) );
end;

{$ENDREGION}

{******************************************************************************}
{******************** TOcvProcFaceDetector ************************************}
{******************************************************************************}

{$REGION 'TOcvProcFaceDetector'}
constructor TOcvProcFaceDetector.Create(owner: TComponent);
begin
  inherited;
  fScoreThreshold:=0.9;
  fNmsThreshold:=0.3;
  fTopK:=5000;
  fModelBinName:='';
  fModelConfigName:='';

  fReconModelBinName:='';
  fReconModelConfigName:='';
  fReconFacesNames:='';
  fReconFeaturesName:='';
  fRecognize:=False;

  fQueueToMain:=nil;
  fQueueToWorkers:=nil;
  SetLength(objdet, fThreadNum);
end;


procedure TOcvProcFaceDetector.activate;
var
  i: Integer;
  faceRec: TOcvDNNFaceRecognizer;
begin
  inherited activate;

  if (fModelBinName='')  then
  begin
    RaiseError(erObjDetFilename,'Error: model file name for binary data must be set');
  end;
  if (fRecognize) and
      ((fReconModelBinName='') or (fReconFacesNames = '') or (fReconFeaturesName='') )  then
  begin
    RaiseError(erObjDetFilename,'Error: for faces recognition, these file names are required: model binary, faces names, features');
  end;

  fQueueToMain:=TMessageQueue<TDetection>.Create(500, getResult);
  fQueueToWorkers:=TMessageQueue<TOCVImage>.Create(500, nil);
  SetLength(objdet, 0);
  SetLength(objdet, fThreadNum);
  SetLength(procThreads, 0);
  SetLength(procThreads, fThreadNum);
  for i:=Low(procThreads) to High(procThreads) do
  begin
      objdet[i]:=TOcvDNNFaceDetect.Create(fModelBinName, fModelConfigName);
      objdet[i].ScoreThreshold:=fScoreThreshold;
      objdet[i].NmsThreshold :=fNmsThreshold;
      objdet[i].TopK :=fTopK;
      if fRecognize then
      begin
        faceRec:=TOcvDNNFaceRecognizer.Create(fReconModelBinName, fReconModelConfigName);
        faceRec.loadFeatures(fReconFeaturesName, fReconFacesNames);
        faceRec.Mode:=FRCompare;
        objdet[i].FaceRecognizer:=faceRec;
        objdet[i].Recognize:=True;
      end;


      procThreads[i]:=TObjDetThread.Create(fQueueToWorkers, fQueueToMain, objdet[i], processError);
  end;

end;

procedure TOcvProcFaceDetector.deactivate;
begin
  isProcessing:=False;

  inherited deactivateThreads;

  if Assigned(fQueueToWorkers) then
  begin
       fQueueToWorkers.Shutdown;
       Sleep(100);
       FreeAndNil(fQueueToWorkers);
  end;
  if Assigned(fQueueToMain) then
  begin
       fQueueToMain.Shutdown;
       Sleep(100);
       FreeAndNil(fQueueToMain);
  end;
end;


procedure TOcvProcFaceDetector.process(const img: TOCVImage);
begin
  if not(isProcessing) then Exit;
  if Length(bufImages) = 0 then
    initBuffer(img);
  if (img.width = bufImages[curBufInd].width) and
     (img.height = bufImages[curBufInd].height) then
        img.copy(bufImages[curBufInd])
  else begin
    FreeAndNil(bufImages[curBufInd]);
    bufImages[curBufInd]:=img.clone();
    bufImages[curBufInd].ID:=curBufInd;
  end;


  if not(fQueueToWorkers.Send(bufImages[curBufInd])) then
     Inc(nrErr);
  Inc(curBufInd);
  if curBufInd>High(bufImages) then
    curBufInd:=Low(bufImages);
end;

procedure TOcvProcFaceDetector.getResult;
var
  dt: TDetection;
begin
  if Assigned(fQueueToMain) then
  begin
     dt:=nil;
     dt:=fQueueToMain.popValue();
     if Assigned(dt) then
          processResult(dt);
  end;
end;


procedure TOcvProcFaceDetector.processResult(const detResult: TDetection);
var
  dt: TDetection;
  drawBackground: Boolean;
begin
  if not(isProcessing) then
  begin
     detResult.Free;
     Exit;
  end;

  drawBackground:=False;
  if detResult.imageId <> curDetectImageId then
  begin
      if Assigned(fOnImageProcessed) then
      begin
        internOcvimg:=bufImages[curDetectImageId];
        fOnImageProcessed(Self, internOcvimg, detections);
      end;
      for dt in detections do
        dt.Free;
      detections.Clear;
      curDetectImageId:=detResult.imageId;
      drawBackground:=True
  end;


  curDetection:=detResult;
  detections.Add(detResult);
  internOcvimg:=bufImages[curDetectImageId];
  if Assigned(fImage) then
         display(internOcvimg, drawBackground);
  curDetection:=nil;
end;


procedure TOcvProcFaceDetector.display(const ocvimg: TOCVImage; const drawBackground: Boolean);
var
  scaleX, scaleY: Single;
  bmp: TBitmap;
begin
  if drawBackground then
     ocvimg.showInImage(fImage);
  bmp:=fImage.Picture.Bitmap;
  scaleX:= bmp.Width / ocvimg.width;
  scaleY := bmp.Height / ocvimg.height;
  curDetection.draw(bmp, scaleX, scaleY);
  fImage.Repaint;
//OutputDebugString(PWideChar('imgId ' + IntToStr(curDetectImageId)) );
end;

{$ENDREGION}

{******************************************************************************}
{******************** TOcvProcMovieWrite **************************************}
{******************************************************************************}

{$REGION 'TOcvProcMovieWrite'}

class procedure TOcvProcMovieWrite.GetVideoCodecList(codecNames: TStrings);
var
  vcodec: TVideoCodec;
  vc: string;
begin
  if not Assigned(codecNames) then
    raise EArgumentException.Create('Codec names list not assigned');
  for vcodec:=Low(tvideocodec) to High(tvideocodec) do
  begin
    vc:=GetEnumName(TypeInfo(TVideoCodec), Ord(vcodec));
    codecNames.Add(vc);
  end;
end;


constructor TOcvProcMovieWrite.Create(owner: TComponent);
begin
  inherited Create(owner);
  fFilename:='';
  fFrameWidth:=640;
  fFrameHeight:=480;
  fFourccCodec:=vcMJPG;
  fFps:=15;
  ocvwriter:=nil;
end;

procedure TOcvProcMovieWrite.SetFourccCodec(val: TVideoCodec);
begin
  fFourccCodec:=val;
end;

procedure TOcvProcMovieWrite.SetFps(val: Integer);
begin
  if (val>0) and (val <= 40) then
    fFps:=val;
end;

procedure TOcvProcMovieWrite.activate;
var
  cvName: CvString_t;
  frameSize: PCvSize_t;
  fourcc: string;
begin
  inherited activate;
  if (fFilename='') then
    RaiseError(erNoFilename, 'Movie file name is empty');
  cvName.pstr:=PAnsiChar(AnsiString(fFilename));
  frameSize:=CvSize_(fFrameWidth, fFrameHeight);
  fourcc:=GetEnumName(TypeInfo(TVideoCodec), Ord(ffourcccodec));
  fourcc:=Copy(fourcc, 3,4);
  ocvwriter:=pCvVideoWriterCreateV3(@cvName,  Ord(TCvVideoCaptureAPIs.CAP_FFMPEG),
            pCvVideoWriterfourcc(fourcc[1], fourcc[2],
                                 fourcc[3], fourcc[4]),
            fFps,
            frameSize);
  pCvSizeDelete(frameSize);
  if not(pCvVideoWriterisOpened(ocvwriter)) then
  begin
    pCvVideoWriterDelete(ocvwriter);
    ocvwriter:=nil;
    RaiseError(erNotOpen,'Unable to open movie file');
  end;
end;

procedure TOcvProcMovieWrite.deactivate;
begin
  if ocvwriter<>nil then
    pCvVideoWriterDelete(ocvwriter);
  ocvwriter:=nil;
  isProcessing:=False;
end;

procedure TOcvProcMovieWrite.display(const ocvimg: TOCVImage; const drawBackground: Boolean);
begin
  ocvimg.showInImage(fImage);
  fImage.Repaint;
end;


procedure TOcvProcMovieWrite.process(const img: TOCVImage);
begin
  if ocvwriter<>nil then
    pCvVideoWriterwrite(ocvwriter, img.PCvMatPtr);
  if Assigned(fOnFrameWrite) then
    begin
      fOnFrameWrite(Self, img);
    end;
  if Assigned(fImage) then
         display(img, True);
end;

{$ENDREGION}

{$IFDEF FPC}
Initialization
{$I pkocvWrapComp.lrs}
{$ENDIF}
end.
