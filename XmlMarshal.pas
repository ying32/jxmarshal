{*******************************************************}
{                                                       }
{       xml序列/反序列化  暂时都只提供简单的            }
{                                                       }
{       版权所有 (C) ying32                             }
{                                                       }
{*******************************************************}

unit XmlMarshal;


interface

uses
  System.SysUtils,
  System.Rtti,
  System.Classes,
  System.Variants,
  System.TypInfo,
{$IFDEF MSWINDOWS}
  Vcl.Forms,
{$ENDIF}
  Xml.XMLIntf,
  Xml.XMLDoc,
  MarshalCommon;


type

  TXmlMarshal = record
  strict private
    {$IFDEF DEBUG}
      class procedure TestPrint(ATypInf: PTypeInfo; AInst: Pointer); static;
    {$ENDIF}
    class procedure PostCallBack_UnMarshal(ANode: IXMLNode; ATypInf: PTypeInfo; AInst: Pointer; AKind: TNodeNameKind); static;
  public
    class function Marshal<T>(ARecord: T; out AResult: string; AKind: TNodeNameKind = nnkNormal): Boolean; static;
    class function UnMarshal<T>(AXmlStr: string; out AResult: T; AKind: TNodeNameKind = nnkNormal): Boolean; static;
    class function UnMarshalStream<T>(AXmlStream: TStream; out AResult: T; AKind: TNodeNameKind = nnkNormal): Boolean; static;
  end;

implementation


  function GetString(ANode: IXMLNode): string;
  begin
    Result := '';
    if Assigned(ANode) then
      Result := VarToStr(ANode.NodeValue);
  end;

  function GetInteger(ANode: IXMLNode): Integer;
  begin
    Result := 0;
    if Assigned(ANode) then
    begin
      if not VarIsNull(ANode.NodeValue) then
        Result := StrToIntDef(string(ANode.NodeValue), 0);
    end;
  end;


class function TXmlMarshal.Marshal<T>(ARecord: T; out AResult: string; AKind: TNodeNameKind): Boolean;
//var
//  LCtx: TSuperRttiContext;
//  LObj: ISuperObject;
begin
//  LCtx := TSuperRttiContext.Create;
//  try
//    LObj := LCtx.AsJson<T>(ARecord);
//    if LObj <> nil then
//    begin
//     // XMLWrite(LObj, nil);
//    end;
//  finally
//    LCtx.Free;
//  end;
end;


class procedure TXmlMarshal.PostCallBack_UnMarshal(ANode: IXMLNode;
  ATypInf: PTypeInfo; AInst: Pointer; AKind: TNodeNameKind);
var
  LRT: TRttiRecordType;
  LRF: TRttiField;
begin
  if (ANode = nil) or (ATypInf = nil) or (AInst = nil) then
    Exit;
  LRT := TRttiContext.Create.GetType(ATypInf).AsRecord;
  for LRF in LRT.GetFields  do
  begin
    case LRF.FieldType.TypeKind of
      tkUString, tkString, tkWString:
        LRF.SetValue(AInst, GetString(ANode.ChildNodes.FindNode(LRF.Name)));
      tkInteger, tkInt64:
        LRF.SetValue(AInst, GetInteger(ANode.ChildNodes.FindNode(LRF.Name)));
      tkRecord:
        PostCallBack_UnMarshal(ANode.ChildNodes.FindNode(LRF.Name),
          LRF.FieldType.Handle, PByte(AInst) + LRF.Offset, AKind);
    end;
  end;
end;

{$IFDEF DEBUG}
class procedure TXmlMarshal.TestPrint(ATypInf: PTypeInfo; AInst: Pointer);
 var
    LRT: TRttiRecordType;
    LRF: TRttiField;
begin
  if (AInst = nil) or (ATypInf = nil) then
    Exit;
  LRT := TRttiContext.Create.GetType(ATypInf).AsRecord;
  for LRF in LRT.GetFields  do
  begin
    case LRF.FieldType.TypeKind of
      tkUString, tkString, tkWString:
        Writeln(LRF.Name, ' = ', LRF.GetValue(AInst).AsString);
      tkInteger, tkInt64:
        Writeln(LRF.Name, ' = ', LRF.GetValue(AInst).AsInteger);
      tkRecord:
        TestPrint(LRF.FieldType.Handle, PByte(AInst) + LRF.Offset);
    end;
  end;
end;
{$ENDIF}

class function TXmlMarshal.UnMarshal<T>(AXmlStr: string; out AResult: T;
  AKind: TNodeNameKind): Boolean;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(AXmlStr, TEncoding.UTF8);
  try
    Result := UnMarshalStream<T>(LStream, AResult, AKind);
  finally
    LStream.Free;
  end;
end;


class function TXmlMarshal.UnMarshalStream<T>(AXmlStream: TStream;
  out AResult: T; AKind: TNodeNameKind): Boolean;
var
  LXml: TXMLDocument;
begin
  LXml := TXMLDocument.Create({$IFDEF MSWINDOWS}Application{$ELSE}nil{$ENDIF});
  try
    AXmlStream.Position := 0;
    LXml.LoadFromStream(AXmlStream, xetUTF_8);
    PostCallBack_UnMarshal(LXml.DocumentElement, TypeInfo(T), @AResult, AKind);
    Result := True;
  finally
    FreeAndNil(LXml);
  end;
end;

end.
