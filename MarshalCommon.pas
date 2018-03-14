unit MarshalCommon;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo;

type

  TNodeNameKind = (nnkNormal, nnkLower, nnkUpper);

  TRecordHelper = record
  strict private
    class procedure PostCallback(ASpace: string; ATypeInfo: PTypeInfo; AInst: Pointer); static;
  public
    class procedure Print<T>(AVal: T); static;
  end;


implementation


{ TRecordHelper }

class procedure TRecordHelper.PostCallback(ASpace: string; ATypeInfo: PTypeInfo;
  AInst: Pointer);

  procedure ReadArr(AV: TValue; AAInst: Pointer);
  var
    LAV: TValue;
    I: Integer;
  begin
    for I := 0 to AV.GetArrayLength - 1 do
    begin
      LAV := AV.GetArrayElement(I);
      case LAV.Kind of
        tkEnumeration:
           Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, LAV.AsBoolean);

        tkFloat:
           Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, LAV.AsExtended);

        tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
           Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, LAV.AsString);

        tkRecord:
            PostCallback('  ', LAV.TypeInfo, LAV.GetReferenceToRawData);

        tkInteger:
            Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, LAV.AsInteger);

        tkInt64:
            Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, LAV.AsInt64);

        tkDynArray, tkArray:
           ReadArr(LAV, LAV.GetReferenceToRawData);

        tkPointer:
           Writeln('', #9#9, LAV.TypeInfo^.Name, #9#9, Cardinal(LAV.AsType<Pointer>).ToHexString(8));
      end;
    end;
  end;


var
  LRT: TRttiRecordType;
  LRF: TRttiField;
  LName: string;
begin
  if (ATypeInfo = nil) or (AInst = nil) then Exit;
  LRT := TRttiContext.Create.GetType(ATypeInfo).AsRecord;
  for LRF in LRT.GetFields do
  begin
    LName := ASpace + LRF.Name;
    case LRF.FieldType.TypeKind of
      tkRecord:
        begin
          Writeln(LName);
          PostCallback(#9, LRF.FieldType.Handle, PByte(AInst) + LRF.Offset);
        end;
      tkArray, tkDynArray:
        begin
          Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, 'array len : ', LRF.GetValue(AInst).GetArrayLength);
          ReadArr(LRF.GetValue(AInst), PByte(AInst) + LRF.Offset);
        end;

      tkPointer:
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, Cardinal(LRF.GetValue(AInst).AsType<Pointer>).ToHexString(8));

      tkEnumeration :
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, LRF.GetValue(AInst).AsBoolean);

      tkUString, tkString, tkWString, tkWChar, tkChar:
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, LRF.GetValue(AInst).AsString);

      tkInt64:
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, LRF.GetValue(AInst).AsInt64);

      tkInteger:
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, LRF.GetValue(AInst).AsInteger);

      tkFloat:
        Writeln(LName, #9#9, LRF.FieldType.Name, #9#9, LRF.GetValue(AInst).AsExtended);
    end;
  end;
end;

class procedure TRecordHelper.Print<T>(AVal: T);
begin
  PostCallback('', TypeInfo(T), @AVal);
end;

end.