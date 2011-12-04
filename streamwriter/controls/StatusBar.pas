unit StatusBar;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, ComCtrls, AppData,
  Functions, LanguageObjects, CommCtrl;

type
  TSWStatusBar = class(TStatusBar)
  private
    FConnected: Boolean;
    FLoggedIn: Boolean;
    FClients: Integer;
    FRecordings: Integer;
    FSpeed: UInt64;
    FSongsSaved: Cardinal;
    FCurrentReceived: UInt64;
    FOverallReceived: UInt64;
    FLastPos: Integer;

    FSpeedBmp: TBitmap;
    IconConnected, IconDisconnected: TIcon;
    IconLoggedIn, IconLoggedOff: TIcon;
    IconGroup: TIcon;

    procedure PaintPanel(Index: Integer);
    procedure FSetSpeed(Value: UInt64);
    procedure FSetCurrentReceived(Value: UInt64);
    procedure FSetOverallReceived(Value: UInt64);
  protected
    procedure DrawPanel(Panel: TStatusPanel; const R: TRect); override;
    procedure Resize; override;
    procedure CNDrawitem(var Message: TWMDrawItem); message CN_DRAWITEM;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  public
    constructor Create(AOwner: TComponent); reintroduce;
    destructor Destroy; override;

    procedure SetState(Connected, LoggedIn: Boolean; Clients, Recordings: Integer; SongsSaved: Cardinal);
    procedure BuildSpeedBmp;
    property Speed: UInt64 read FSpeed write FSetSpeed;
    property CurrentReceived: UInt64 read FCurrentReceived write FSetCurrentReceived;
    property OverallReceived: UInt64 read FOverallReceived write FSetOverallReceived;
  end;

implementation

{ TSWStatusBar }

procedure TSWStatusBar.BuildSpeedBmp;
var
  P: Integer;
  NewBmp: TBitmap;
begin
  NewBmp := TBitmap.Create;
  NewBmp.Width := 35;
  NewBmp.Height := 15;
  NewBmp.Canvas.Pen.Width := 1;
  NewBmp.Canvas.Brush.Color := clBtnFace;
  NewBmp.Canvas.FillRect(Rect(0, 0, NewBmp.Width, NewBmp.Height));

  if FSpeedBmp <> nil then
  begin
    NewBmp.Canvas.Draw(-1, 0, FSpeedBmp);
  end;
  FSpeedBmp.Free;
  FSpeedBmp := NewBmp;

  P := 0;
  if AppGlobals.MaxSpeed > 0 then
  begin
    P := Trunc(((FSpeed / 1024) / AppGlobals.MaxSpeed) * NewBmp.Height - 1);
    if P > NewBmp.Height - 1 then
      P := NewBmp.Height - 1;
    if P < 1 then
      P := 1;
  end;

  FSpeedBmp.Canvas.MoveTo(0, FSpeedBmp.Height - 1);
  FSpeedBmp.Canvas.LineTo(FSpeedBmp.Width - 1, FSpeedBmp.Height - 1);

  FSpeedBmp.Canvas.MoveTo(FSpeedBmp.Width - 1, FSpeedBmp.Height - P);
  FSpeedBmp.Canvas.LineTo(FSpeedBmp.Width - 1, FSpeedBmp.Height);


  if P > 9 then
  begin
    FSpeedBmp.Canvas.Pixels[FSpeedBmp.Width - 1, FSpeedBmp.Height - 11] := HTML2Color('4b1616');
  end;

  if P > 10 then
  begin
    FSpeedBmp.Canvas.Pixels[FSpeedBmp.Width - 1, FSpeedBmp.Height - 12] := HTML2Color('722222');
  end;

  if P > 11 then
  begin
    FSpeedBmp.Canvas.Pixels[FSpeedBmp.Width - 1, FSpeedBmp.Height - 13] := HTML2Color('9d2626');
  end;

  if P > 12 then
  begin
    FSpeedBmp.Canvas.Pixels[FSpeedBmp.Width - 1, FSpeedBmp.Height - 14] := HTML2Color('c42c2c');
  end;

  if P > 13 then
  begin
    FSpeedBmp.Canvas.Pixels[FSpeedBmp.Width - 1, FSpeedBmp.Height - 15] := HTML2Color('d71717');
  end;


  FLastPos := P;
end;

procedure TSWStatusBar.CNDrawitem(var Message: TWMDrawItem);
begin
  inherited;

  Message.Result := 1;
end;

constructor TSWStatusBar.Create(AOwner: TComponent);
var
  P: TStatusPanel;
begin
  inherited;

  Hint := 'Users/active streams';
  ShowHint := True;
  Height := 19;

  IconConnected := TIcon.Create;
  IconConnected.Handle := LoadImage(HInstance, 'CONNECT', IMAGE_ICON, 15, 15, LR_DEFAULTCOLOR);
  IconDisconnected := TIcon.Create;
  IconDisconnected.Handle := LoadImage(HInstance, 'DISCONNECT', IMAGE_ICON, 15, 15, LR_DEFAULTCOLOR);
  IconLoggedIn := TIcon.Create;
  IconLoggedIn.Handle := LoadImage(HInstance, 'USER_GO', IMAGE_ICON, 15, 15, LR_DEFAULTCOLOR);
  IconLoggedOff := TIcon.Create;
  IconLoggedOff.Handle := LoadImage(HInstance, 'USER_DELETE', IMAGE_ICON, 15, 15, LR_DEFAULTCOLOR);
  IconGroup := TIcon.Create;
  IconGroup.Handle := LoadImage(HInstance, 'GROUP', IMAGE_ICON, 15, 15, LR_DEFAULTCOLOR);

  P := Panels.Add;
  P.Width := 120;
  P.Style := psOwnerDraw;

  P := Panels.Add;
  P.Width := 90;
  P.Style := psOwnerDraw;

  P := Panels.Add;
  if AppGlobals.LimitSpeed and (AppGlobals.MaxSpeed > 0) then
    P.Width := 115
  else
    P.Width := 75;
  P.Style := psOwnerDraw;

  P := Panels.Add;
  P.Width := 190;
  P.Style := psOwnerDraw;

  P := Panels.Add;
  P.Width := 100;
  P.Style := psOwnerDraw;
end;

destructor TSWStatusBar.Destroy;
begin
  IconConnected.Free;
  IconDisconnected.Free;
  IconLoggedIn.Free;
  IconLoggedOff.Free;
  IconGroup.Free;
  FSpeedBmp.Free;

  inherited;
end;

procedure TSWStatusBar.DrawPanel(Panel: TStatusPanel; const R: TRect);
begin
  inherited;

  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(R);

  case Panel.Index of
    0:
      begin
        if FConnected then
        begin
          Canvas.Draw(R.Left, R.Top, IconConnected);
          Canvas.TextOut(R.Left + 38, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(_('Connected')) div 2, _('Connected'));
        end else
        begin
          Canvas.Draw(R.Left, R.Top, IconDisconnected);
          Canvas.TextOut(R.Left + 38, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(_('Connecting...')) div 2, _('Connecting...'));
        end;

        if FLoggedIn then
          Canvas.Draw(R.Left + 18, R.Top, IconLoggedIn)
        else
          Canvas.Draw(R.Left + 18, R.Top, IconLoggedOff);
      end;
    1:
      begin
        Canvas.Draw(R.Left, R.Top, IconGroup);
        Canvas.TextOut(R.Left + 20, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(IntToStr(FClients) + '/' + IntToStr(FRecordings)) div 2, IntToStr(FClients) + '/' + IntToStr(FRecordings));
      end;
    2:
      begin
        Canvas.TextOut(R.Left + 2, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(MakeSize(FSpeed) + '/s') div 2, MakeSize(FSpeed) + '/s');
        if AppGlobals.LimitSpeed and (AppGlobals.MaxSpeed > 0) then
        begin
          Panels[2].Width := 115;
          if FSpeedBmp <> nil then
            Canvas.Draw(R.Right - FSpeedBmp.Width - 2, R.Top, FSpeedBmp);
        end else
          Panels[2].Width := 75;
      end;
    3:
      Canvas.TextOut(R.Left + 2, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(Format(_('%s/%s received'), [MakeSize(FCurrentReceived), MakeSize(FOverallReceived)])) div 2, Format(_('%s/%s received'), [MakeSize(FCurrentReceived), MakeSize(FOverallReceived)]));
    4:
      Canvas.TextOut(R.Left + 2, R.Top + ((R.Bottom - R.Top) div 2) - Canvas.TextHeight(Format(_('%d songs saved'), [FSongsSaved])) div 2, Format(_('%d songs saved'), [FSongsSaved]));
  end;
end;

procedure TSWStatusBar.FSetCurrentReceived(Value: UInt64);
var
  C: Boolean;
begin
  C := FCurrentReceived <> Value;
  FCurrentReceived := Value;

  if C then
    PaintPanel(3);
end;

procedure TSWStatusBar.FSetOverallReceived(Value: UInt64);
var
  C: Boolean;
begin
  C := FOverallReceived <> Value;
  FOverallReceived := Value;

  if C then
    PaintPanel(3);
end;

procedure TSWStatusBar.FSetSpeed(Value: UInt64);
begin
  FSpeed := Value;
  BuildSpeedBmp;
  PaintPanel(2);
end;

procedure TSWStatusBar.PaintPanel(Index: Integer);
var
  R: TRect;
begin
  Perform(SB_GETRECT, Index, Integer(@R));
  R.Right := R.Right - 2;
  R.Top := R.Top + 1;
  R.Left := R.Left + 2;
  R.Bottom := R.Bottom - 1;
  DrawPanel(Panels[Index], R);
end;

procedure TSWStatusBar.Resize;
begin
  inherited;

  BuildSpeedBmp;
end;

procedure TSWStatusBar.SetState(Connected, LoggedIn: Boolean; Clients, Recordings: Integer; SongsSaved: Cardinal);
var
  OldConnected, OldLoggedIn: Boolean;
  OldClients, OldRecordings: Integer;
  OldSongsSaved: Cardinal;
begin
  OldConnected := FConnected;
  OldLoggedIn := FLoggedIn;
  OldClients := FClients;
  OldRecordings := FRecordings;
  OldSongsSaved := FSongsSaved;

  FConnected := Connected;
  FLoggedIn := LoggedIn;
  if Connected then
  begin
    FClients := Clients;
    FRecordings := Recordings;
  end else
  begin
    FClients := 0;
    FRecordings := 0;
  end;

  FSongsSaved := SongsSaved;

  if (OldConnected <> FConnected) or (OldLoggedIn <> FLoggedIn) then
    PaintPanel(0);
  if (OldClients <> FClients) or (OldRecordings <> FRecordings) then
    PaintPanel(1);

  if OldSongsSaved <> FSongsSaved then
    PaintPanel(4);
end;

procedure TSWStatusBar.WMPaint(var Message: TWMPaint);
var
  i: Integer;
begin
  inherited;

  for i := 0 to Panels.Count - 1 do
  begin
    PaintPanel(i);
  end;
end;

end.
