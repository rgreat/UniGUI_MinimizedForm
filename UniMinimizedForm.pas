unit UniMinimizedForm;

interface

uses
  Types, Classes, SysUtils, Vcl.Forms, uniGUITypes, uniGUIServer, uniGUIApplication, uniGUIClasses, uniGUIForm,
  System.Actions, Vcl.ActnList, ArrayEx;


type
  TScreenResizeEvent = procedure(Sender: TObject; AWidth, AHeight: Integer) of object;

  TUniForm = class(uniGUIForm.TUniForm)
  private
    type
      TScreenResizeData = record
        MainForm : TUniForm;
        Event    : TScreenResizeEvent;
      end;
    var

    ButtonMinimize    : TUniToolItem;
    ButtonRestore     : TUniToolItem;

    FOnMinimize       : TNotifyEvent;
    FOnRestore        : TNotifyEvent;
    FOnMaximize       : TNotifyEvent;

    FMinimizedOldPos  : TRect;
    FMinimizedPos     : TRect;
    FOldWindowState   : TWindowState;
    FRestrictFormSize : boolean;

    FOnOldScrResize   : TArrayEx<TScreenResizeData>;

    FWindowState      : TWindowState;

    function GetMinimisedPos: TPoint;

    procedure HandleMinimize(Sender: TObject);
    procedure HandleRestore(Sender: TObject);
    procedure HandleResize(Sender: TObject);
    procedure HandleScreenResize(Sender: TObject; AWidth, AHeight: Integer);

    procedure ValidateWindowsSize;

    procedure OnSetWindowState(const Value: TWindowState);

    type
      TMinimizedForms = TArrayEx<TUniForm>;

    class var MinimizedForms: TMinimizedForms;

    class constructor Create;
    class destructor Destroy;
  public

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property OnMinimize: TNotifyEvent read FOnMinimize write FOnMinimize;
    property OnRestore: TNotifyEvent read FOnRestore write FOnRestore;
    property OnMaximize: TNotifyEvent read FOnMaximize write FOnMaximize;
    property WindowState: TWindowState read FWindowState write OnSetWindowState;
    property RestrictFormSize: boolean read FRestrictFormSize write FRestrictFormSize default False;
  end;

implementation

uses UniGUIVars, System.Math, System.UITypes;

{ TUniForm }


class constructor TUniForm.Create;
begin
  TUniForm.MinimizedForms.Clear;
  TUniForm.MinimizedForms.DoFreeData:=False;
end;

class destructor TUniForm.Destroy;
begin
  TUniForm.MinimizedForms.Clear;
end;

procedure TUniForm.HandleScreenResize(Sender: TObject; AWidth, AHeight: Integer);
begin
  try
    if TUniForm.MinimizedForms.IsEmpty then begin
      try
        TUniForm(Sender).OnResize:=nil;
      except
      end;
      Exit;
    end;

    var UA:=UniApplication;
    for var Form in TUniForm.MinimizedForms do begin
      try
        if (Form.UniApplication=UA) and (Form<>Self) then begin
          Form.HandleResize(Form);
        end;
      except
        try
          TUniForm.MinimizedForms.DeleteValues(Form);
        except
        end;
      end;
    end;

    if Assigned(UniSession) then begin
      var MainForm:=TUniForm(UniSession.UniMainModule.MainForm);

      for var Item in FOnOldScrResize do begin
        if Item.MainForm=MainForm then begin
          Item.Event(Sender,AWidth,AHeight);
        end;
      end;
    end;
  except
    try
      TUniForm(Sender).OnResize:=nil;
    except
    end;
  end;
end;

constructor TUniForm.Create(AOwner: TComponent);
begin
  inherited;

  BorderIcons:=BorderIcons-[TBorderIcon.biMinimize]-[TBorderIcon.biMaximize];

  ButtonMinimize:=TUniToolItem(ToolButtons.Add);
  ButtonMinimize.ToolType:='minimize';
  ButtonMinimize.Hint:='Ñâåðíóòü îêíî';
  ButtonMinimize.Action:=TAction.Create(Self);
  ButtonMinimize.Action.OnExecute:=HandleMinimize;

  ButtonRestore:=TUniToolItem(ToolButtons.Add);
  ButtonRestore.ToolType:='maximize';
  ButtonRestore.Hint:='Ðàçâåðíóòü îêíî';
  ButtonRestore.Action:=TAction.Create(Self);
  ButtonRestore.Action.OnExecute:=HandleRestore;

  TUniForm.MinimizedForms.AddUnique(Self);

  FWindowState:=inherited WindowState;

  var MainForm:=TUniForm(UniSession.UniMainModule.MainForm);
  if Assigned(MainForm.OnScreenResize) then begin
    var Found:=False;
    for var Item in FOnOldScrResize do begin
      if Item.MainForm=MainForm then begin
        Found:=True;
        Break;
      end;
    end;
    if not Found then begin
      var Item: TScreenResizeData;
      Item.MainForm:=MainForm;
      Item.Event:=MainForm.OnScreenResize;
      FOnOldScrResize.Add(Item);
    end;
  end;
  MainForm.OnScreenResize:=HandleScreenResize;
end;

destructor TUniForm.Destroy;
begin
  try
    OnScreenResize:=nil;
    ButtonMinimize.Action.Free;
    ButtonRestore.Action.Free;
    TUniForm.MinimizedForms.DeleteValues(Self);
  except
  end;

  inherited;
end;

function TUniForm.GetMinimisedPos: TPoint;
begin
  if FMinimizedPos.Width>0 then begin
    Result:=FMinimizedPos.TopLeft;
    Exit;
  end;

  Result.X:=5;
  Result.Y:=UniApplication.ScreenHeight-26;

  for var Form in TUniForm.MinimizedForms do begin
    if Form.UniApplication<>UniApplication then Continue;
    if Form.FMinimizedPos.Width=0 then Continue;

    Result.X:=max(Form.FMinimizedPos.Left+146,Result.X); ;
  end;
end;

procedure TUniForm.HandleMinimize(Sender: TObject);
begin
  if Assigned(FOnMinimize) then begin
    FOnMinimize(Self);
  end;

  var Pos:=GetMinimisedPos;

  FMinimizedOldPos.Left:=Left;
  FMinimizedOldPos.Top:=Top;
  FMinimizedOldPos.Width:=Width;
  FMinimizedOldPos.Height:=Height;

  FOldWindowState:=FWindowState;

  FMinimizedPos.TopLeft:=Pos;
  FMinimizedPos.Width:=140;

  Left:=FMinimizedPos.TopLeft.X;
  Top:=FMinimizedPos.TopLeft.Y;
  Width:=FMinimizedPos.Width;
  Height:=FMinimizedPos.Height;

  FWindowState:=TWindowState.wsMinimized;

  ButtonMinimize.Visible:=False;
  ButtonRestore.ToolType:='restore';
  ButtonRestore.Hint:='Âîññòàíîâèòü îêíî';
end;

procedure TUniForm.HandleRestore(Sender: TObject);
begin
  if FWindowState=TWindowState.wsNormal then begin
    if Assigned(FOnMaximize) then begin
      FOnMaximize(Self);
    end;

    FMinimizedOldPos.Left:=Left;
    FMinimizedOldPos.Top:=Top;
    FMinimizedOldPos.Width:=Width;
    FMinimizedOldPos.Height:=Height;

    FOldWindowState:=FWindowState;

    Left:=0;
    Top:=0;
    Width:=UniApplication.ScreenWidth;
    Height:=UniApplication.ScreenHeight;

    FWindowState:=TWindowState.wsMaximized;

    ButtonMinimize.Visible:=True;
    ButtonRestore.ToolType:='restore';
    ButtonRestore.Hint:='Âîññòàíîâèòü îêíî';
  end else begin
    if Assigned(FOnRestore) then begin
      FOnRestore(Self);
    end;

    Left:=FMinimizedOldPos.Left;
    Top:=FMinimizedOldPos.Top;
    Width:=FMinimizedOldPos.Width;
    Height:=FMinimizedOldPos.Height;
    FWindowState:=FOldWindowState;

    ButtonMinimize.Visible:=True;
    ButtonRestore.ToolType:='maximize';
    ButtonRestore.Hint:='Ðàçâåðíóòü îêíî';
  end;
end;

procedure TUniForm.HandleResize(Sender: TObject);
begin
  case FWindowState of
    TWindowState.wsMinimized: begin
      Top:=UniApplication.ScreenHeight-26;
    end;
    TWindowState.wsNormal: begin
      ValidateWindowsSize;
    end;
    TWindowState.wsMaximized: begin
      Left:=0;
      Top:=0;
      Width:=UniApplication.ScreenWidth;
      Height:=UniApplication.ScreenHeight;
    end;
  end;
end;

procedure TUniForm.ValidateWindowsSize;
begin
  if Left+Width>UniApplication.ScreenWidth then Left:=UniApplication.ScreenWidth-Width;
  if Top+Height>UniApplication.ScreenHeight then Top:=UniApplication.ScreenHeight-Height;
  if Left<0 then Left:=0;
  if Top<0 then Top:=0;
  if FRestrictFormSize then begin
    if Width>UniApplication.ScreenWidth then Width:=UniApplication.ScreenWidth;
    if Height>UniApplication.ScreenHeight then Height:=UniApplication.ScreenHeight;
  end;
end;

procedure TUniForm.OnSetWindowState(const Value: TWindowState);
begin
  if Value=FWindowState then Exit;

  case Value of
    TWindowState.wsNormal: begin
      HandleRestore(nil);
    end;
    TWindowState.wsMinimized: begin
      HandleMinimize(nil);
    end;
    TWindowState.wsMaximized: begin
      FWindowState:=TWindowState.wsNormal;
      HandleRestore(nil);
    end;
  end;
end;


end.

