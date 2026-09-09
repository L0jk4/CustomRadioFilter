#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

DynamicDetour g_hDetour_ConstructRadioFilter;

Handle g_hSDKCall_AddRecipient;
Handle g_hSDKCall_RemoveRecipientByPlayerIndex;
Handle g_hSDKCall_GetRecipientCount;
Handle g_hSDKCall_GetRecipientIndex;

public Plugin myinfo =
{
	name        = "CustomRadioFilter",
	author      = "Lojka",
	description = "",
	version     = "1.0",
	url         = "https://github.com/L0jk4/CustomRadioFilter"
};

#define GAMECONF_FILE   "CustomRadioFilter.games"
public void OnPluginStart()
{
	GameData gd = new GameData(GAMECONF_FILE);
	if (gd == null)
	{
		delete gd;
		SetFailState("Failed to load gamedata file: %s", GAMECONF_FILE);
	}

	// void CCSPlayer::ConstructRadioFilter( CRecipientFilter& filter )
	g_hDetour_ConstructRadioFilter = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if (g_hDetour_ConstructRadioFilter == null ||
	    !g_hDetour_ConstructRadioFilter.SetFromConf(gd, SDKConf_Signature, "CCSPlayer::ConstructRadioFilter"))
	{
		delete gd;
		SetFailState("Failed to find signature for \"CCSPlayer::ConstructRadioFilter\"");
	}
	g_hDetour_ConstructRadioFilter.AddParam(HookParamType_ObjectPtr);
	if (!g_hDetour_ConstructRadioFilter.Enable(Hook_Post, Detour_ConstructRadioFilter))
	{
		delete gd;
		SetFailState("Failed to enable detour on \"CCSPlayer::ConstructRadioFilter\"");
	}

	InitSDKCalls_CRecipientFilter(gd);
	delete gd;
}

// void CCSPlayer::ConstructRadioFilter( CRecipientFilter& filter )
public MRESReturn Detour_ConstructRadioFilter(int sender, DHookParam hParams)
{
	M_CRecipientFilter filter = view_as<M_CRecipientFilter>(hParams.GetAddress(1));
	int numRecipients = filter.GetRecipientCount();
	for ( int slot = 0; slot < numRecipients; slot++)
	{
		int client = filter.GetRecipientIndex(slot);
		// if ClientFilter[client] == Filter_PartnerOnly && sender != PartnerOf(client)
		filter.RemoveRecipient(client);
	}

	return MRES_Supercede;
}

void InitSDKCalls_CRecipientFilter(GameData gd)
{
	// void CRecipientFilter::AddRecipient( const CBasePlayer *player )
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CRecipientFilter::AddRecipient");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer); // const CBasePlayer *player
	g_hSDKCall_AddRecipient = EndPrepSDKCall();
	if (g_hSDKCall_AddRecipient == null)
	{
		delete gd;
		SetFailState("Failed to create SDKCall for \"CRecipientFilter::AddRecipient\"");
	}

	// virtual int	GetRecipientCount( void ) const;
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Virtual, "CRecipientFilter::GetRecipientCount");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCall_GetRecipientCount = EndPrepSDKCall();
	if (g_hSDKCall_GetRecipientCount == null)
	{
		delete gd;
		SetFailState("Failed to create SDKCall for \"CRecipientFilter::GetRecipientCount\"");
	}

	// virtual int	GetRecipientIndex( int slot ) const;
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Virtual, "CRecipientFilter::GetRecipientIndex");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCall_GetRecipientIndex = EndPrepSDKCall();
	if (g_hSDKCall_GetRecipientIndex == null)
	{
		delete gd;
		SetFailState("Failed to create SDKCall for \"CRecipientFilter::GetRecipientIndex\"");
	}

	// void	RemoveRecipientByPlayerIndex( int playerindex );
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CRecipientFilter::RemoveRecipientByPlayerIndex");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
	g_hSDKCall_RemoveRecipientByPlayerIndex = EndPrepSDKCall();
	if (g_hSDKCall_RemoveRecipientByPlayerIndex == null)
	{
		delete gd;
		SetFailState("Failed to create SDKCall for \"CRecipientFilter::RemoveRecipientByPlayerIndex\"");
	}
}

methodmap AddressBase
{
	property Address Address
	{
		public get() { return view_as<Address>(this); }
	}
}
methodmap M_CRecipientFilter < AddressBase
{
	public M_CRecipientFilter(Address addr)
	{
		return view_as<M_CRecipientFilter>(addr);
	}

	public void AddRecipient( int playerindex )
	{
		SDKCall(g_hSDKCall_AddRecipient, this.Address, playerindex);
	}
	public void	RemoveRecipient( int playerindex )
	{
		SDKCall(g_hSDKCall_RemoveRecipientByPlayerIndex, this.Address, playerindex);
	}
	public int	GetRecipientCount()
	{
		return SDKCall(g_hSDKCall_GetRecipientCount, this.Address);
	}
	public int	GetRecipientIndex( int slot )
	{
		return SDKCall(g_hSDKCall_GetRecipientIndex, this.Address, slot);
	}
}
