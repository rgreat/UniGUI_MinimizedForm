unit UniMinimizedForm;

interface

uses
  Types, Classes, SysUtils, Vcl.Forms, uniGUITypes, uniGUIServer, uniGUIApplication, uniGUIClasses, uniGUIForm,
  System.Actions, Vcl.ActnList, Indexes;


type
  TScreenResizeEvent = procedure(Sender: TObject; AWidth, AHeight: Integer) of object;

  TUniForm = class(uniGUIForm.TUniForm)
  private
    ButtonMinimize     : TUniToolItem;
    ButtonRestore      : TUniToolItem;

    FOnMinimize        : TNotifyEvent;
    FOnRestore         : TNotifyEvent;
    FOnMaximize        : TNotifyEvent;

    FMinimizedOldPos   : TRect;
    FMinimizedPos      : TRect;
    FOldWindowState    : TWindowState;
    FRestrictFormSize  : boolean;

    FWindowState       : TWindowState;

    FBaseAjaxEvent     : TUniAjaxEvent;

    function GetMinimisedPos: TPoint;

    procedure HandleMinimize(Sender: TObject);
    procedure HandleRestore(Sender: TObject);
    procedure HandleResize(Sender: TObject);

    procedure ValidateWindowsSize;

    procedure OnSetWindowState(const Value: TWindowState);
    procedure OnSetAjaxEvent(const Value: TUniAjaxEvent);

    type
      TMainFormData = record
        MainForm       : uniGUIForm.TUniForm;
        OnScreenResize : TScreenResizeEvent;
      end;
    class var MinimizedForms: TArrayEx<TUniForm>;
    class var MainForms: TArrayEx<TMainFormData>;

    class procedure HandleScreenResize(Sender: TObject; AWidth, AHeight: Integer);

    class constructor Create;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

  protected
    procedure DoAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
    procedure Loaded; override;
  published
    property OnAjaxEvent: TUniAjaxEvent read FBaseAjaxEvent write OnSetAjaxEvent;
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
  TUniForm.MinimizedForms.OwnValues:=False;
end;

class procedure TUniForm.HandleScreenResize(Sender: TObject; AWidth, AHeight: Integer);
begin
  if not Assigned(Sender) or TUniForm.MinimizedForms.IsEmpty then Exit;

  var MainForm:=TUniForm(Sender);
  var UniApplication:=MainForm.UniApplication;

  var MainFormOnScreenResize: TScreenResizeEvent := nil;

  for var Form in TUniForm.MinimizedForms do begin
    if Form.UniApplication=UniApplication then begin
      Form.HandleResize(Form);
    end;
  end;

  for var FormData in TUniForm.MainForms do begin
    if MainForm=FormData.MainForm then begin
      FormData.OnScreenResize(Sender,AWidth,AHeight);
    end;
  end;
end;

constructor TUniForm.Create(AOwner: TComponent);
begin
  inherited;

  BorderIcons:=BorderIcons-[TBorderIcon.biMinimize]-[TBorderIcon.biMaximize];

  ButtonMinimize:=TUniToolItem(ToolButtons.Add);
  ButtonMinimize.ToolType:='minimize';
  ButtonMinimize.Hint:='Свернуть окно';
  ButtonMinimize.Action:=TAction.Create(Self);
  ButtonMinimize.Action.OnExecute:=HandleMinimize;

  ButtonRestore:=TUniToolItem(ToolButtons.Add);
  ButtonRestore.ToolType:='maximize';
  ButtonRestore.Hint:='Развернуть окно';
  ButtonRestore.Action:=TAction.Create(Self);
  ButtonRestore.Action.OnExecute:=HandleRestore;

  TUniForm.MinimizedForms.AddUnique(Self);

  FWindowState:=inherited WindowState;
  inherited OnAjaxEvent:=DoAjaxEvent;

  if Assigned(UniSession) then begin
    var MainForm:=TUniForm(UniSession.UniMainModule.MainForm);
    if Assigned(MainForm) then begin
      if Assigned(MainForm.OnScreenResize) then begin
        var Found:=False;
        for var FormData in TUniForm.MainForms do begin
          if MainForm=FormData.MainForm then begin
            Found:=True;
            Break;
          end;
        end;
        if not Found then begin
          var FormData: TMainFormData;
          FormData.MainForm:=MainForm;
          FormData.OnScreenResize:=MainForm.OnScreenResize;
          TUniForm.MainForms.Add(FormData);
        end;
      end;
      MainForm.OnScreenResize:=HandleScreenResize;
    end;
  end;
end;

destructor TUniForm.Destroy;
begin
  try
    var CurMainForm:=UniSession.UniMainModule.MainForm;

    var Found:=False;
    for var Form in TUniForm.MinimizedForms do begin
      if Form=Self then Continue;
      if Form.UniSession.UniMainModule.MainForm=CurMainForm then begin
        Found:=True;
        Break;
      end;
    end;

    if not Found then begin
      for var i:=TUniForm.MainForms.High downto 0 do begin
        if CurMainForm=TUniForm.MainForms[i].MainForm then begin
          TUniForm.MainForms.Delete(i);
          Break;
        end;
      end;
    end;

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
  ButtonRestore.Hint:='Восстановить окно';
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
    ButtonRestore.Hint:='Восстановить окно';
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
    ButtonRestore.Hint:='Развернуть окно';
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
const
  MinBorder = 30;
begin
  if Left>UniApplication.ScreenWidth-MinBorder then Left:=UniApplication.ScreenWidth-MinBorder;
  if Top+Height>UniApplication.ScreenHeight then Top:=UniApplication.ScreenHeight-Height;

  if Left+Width<MinBorder then Left:=MinBorder-Width;
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

procedure TUniForm.OnSetAjaxEvent(const Value: TUniAjaxEvent);
begin
  FBaseAjaxEvent:=Value;
end;

procedure TUniForm.DoAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
begin
  if EventName='HeaderDblClick' then begin
    case WindowState of
      TWindowState.wsNormal: WindowState:=TWindowState.wsMaximized;
      TWindowState.wsMinimized: WindowState:=TWindowState.wsNormal;
      TWindowState.wsMaximized: WindowState:=TWindowState.wsNormal;
    end;
  end;

  if EventName='move' then begin
    HandleResize(Self);
  end;

  if Assigned(FBaseAjaxEvent) then begin
    FBaseAjaxEvent(Sender,EventName,Params);
  end;
end;

procedure TUniForm.Loaded;
begin
  inherited;

  var JS:=ClientEvents.ExtEvents.Values['window.boxready'];

  if JS<>'' then begin
    var P:=JS.LastIndexOf('}');
    if P>0 then begin
      JS:=Copy(JS,1,P-1)+#13#10+
          '  sender.header.el.on(''dblclick'', function(){'#13#10+
          '    ajaxRequest(sender, ''HeaderDblClick'', []);'#13#10+
          '  });'#13#10+
          Copy(JS,P+1,Length(JS)-P);
    end;
  end else begin
    JS:='function window.boxready(sender, width, height, eOpts)'#13#10+
        '{'#13#10+
        '  sender.header.el.on(''dblclick'', function(){'#13#10+
        '    ajaxRequest(sender, ''HeaderDblClick'', []);'#13#10+
        '  });'+
        #13#10'}';
  end;

  ClientEvents.ExtEvents.Values['window.boxready']:=JS;
end;

end.


