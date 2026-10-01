if (scr_freeze_if_paused()) exit;
switch (state) 
{
    case "IDLE":
        familiar_raven_idle();
        break;
        
    case "FOLLOW":
		familiar_raven_follow();
        break;
        
    case "ATTACK":
		
		break;
	
    default:
        state = "IDLE"; // Catch-all safety net
        break;
}

