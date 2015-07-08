CREATE OR REPLACE PROCEDURE ups_reprint_tcl(p_prt_reqstr          in prt_q_dest.prt_reqstr%type,
                                            object_type           in varchar2,
                                            print_object          in varchar2,
                                            reprint_or_regenerate in varchar2,
                                            v_output              IN OUT varchar2
                                            
                                            )

  /*
  *  Package           : UPS_REPRINT_TCL
  *  DESCRIPTION       : REPRINT or GENERATE TCL FROM RF
  *  AUTHOR            : Chris Spencer
  *
  *  ****************************** MODIFICATION LOG *******************************
  *  DATE        BY                      DESCRIPTION
  *  06/15/2015  Chris Spencer           Version 1.0
  *  06/23/2015  Chris Spencer            Version 1.1
  *
  */

 AS

  v_valid_req          char;
  v_cd_master_id       cd_master.cd_master_id%TYPE;
  v_valid_input        varchar2(500);
  v_sequence           NUMBER;
  v_task_id            task_dtl.task_id%TYPE;
  v_tote_print_enabled char := 'N';
  v_wave_nbr           carton_hdr.wave_nbr%TYPE;
  v_carton_nbr         carton_hdr.carton_nbr%TYPE;
  v_convey_flag        item_master.convey_flag%TYPE;
  v_sku_id             item_master.sku_id%TYPE;
  v_printq_name        ups_tcl_table.prt_q_name%TYPE;
  v_stat_code          ups_tcl_table.stat_code%TYPE;

  number_of_rows_updated number;
  lNumRecs               number := 0;

  p_rc NUMBER;

begin

  if p_prt_reqstr is null then
    v_output := 'INVALID REQSTR';
    return;
  end if;

  --user has entered only print requestor.

  IF (p_prt_reqstr IS NOT NULL AND object_type IS NULL AND
     print_object is NULL AND reprint_or_regenerate is NULL) THEN
  
    BEGIN
    
      select 'Y'
        into v_valid_req
        FROM sys_code
       WHERE code_type = '074'
         AND code_id = p_prt_reqstr;
    
    EXCEPTION
      WHEN No_Data_Found THEN
        v_output := 'INVALID REQSTR';
        return;
    END;
  
    if v_valid_req = 'Y' then
      v_output := 'Y';
    
      return;
    end if;
  
    --user has only entered print requestor, object_type(PKT,CARTON,WAVE,TOTE) , print object(wave#,pkt#,carton#,tote#)
  
  elsif (p_prt_reqstr is not NULL and object_type is not NULL AND
        print_object is not NULL and reprint_or_regenerate IS NULL) THEN
  
    Begin
    
      if (object_type = 'C' or object_type = 'c') then
        Begin
          select distinct cd_master_id
            into v_cd_master_id
            from carton_hdr ch
           where ch.carton_nbr = print_object;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'Invalid Carton';
            return;
          
        END;
      
      elsif (object_type = 'W' or object_type = 'w') then
        Begin
          select distinct cd_master_id
            into v_cd_master_id
            from carton_hdr ch
          
           where ch.wave_nbr = print_object;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'Invalid Wave';
            return;
        end;
      elsif (object_type = 'K' or object_type = 'k') then
      
        Begin
          select distinct cd_master_id
            into v_cd_master_id
            from carton_hdr ch
          
           where ch.pkt_ctrl_nbr = print_object;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'Invalid Pkt';
            return;
        End;
      
      elsif (object_type = 'T' or object_type = 't') then
        Begin
          select td.cd_master_id, max(th.task_id)
            into v_cd_master_id, v_task_id
            from task_hdr th
            JOIN task_dtl td
              on th.task_id = td.task_id
           where th.doc_id = print_object
           group by td.cd_master_id;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'Invalid Tote';
            return;
        End;
      
      end if;
    
    EXCEPTION
      WHEN No_Data_Found THEN
        v_output := 'Invalid Entry';
        return;
    End;
    Begin
    
      Select substr(misc_flags, 1, 1)
        into v_tote_print_enabled
        from Cd_Sys_Code
       Where Rec_Type = 'C'
         And Code_Type = 'TCL'
         And Cd_Master_Id = v_cd_master_id;
    
      if (v_tote_print_enabled = 'Y') then
        v_output := 'Y';
        return;
      
      end if;
    
    EXCEPTION
      WHEN No_Data_Found THEN
        v_output := 'Invalid Co/Div';
        return;
      
    END;
  
    if (v_tote_print_enabled = 'Y') then
    
      if (object_type = 'C' or object_type = 'c') then
      
        Begin
        
          select 'Y'
            into v_valid_input
            from carton_hdr ch
           where ch.carton_nbr = print_object
             and (ch.cd_master_id = v_cd_master_id);
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'Invalid CARTON';
            return;
          
        END;
      
        if v_valid_input = 'Y' then
          v_output := 'Y';
          return;
        else
          v_output := 'INVALID CARTON';
          return;
        end if;
      
      elsif (object_type = 'W' or object_type = 'w') then
      
        Begin
        
          select 'Y'
            into v_valid_input
            from carton_hdr ch
          ---join WAVE_RULE_PARM wrp
          --on WRP.RULE_ID = CH.SEL_RULE_ID
           where ch.wave_nbr = print_object
             and (ch.cd_master_id = v_cd_master_id) HAVING
           count(*) > 0;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'INVALID_WAVE';
            RETURN;
        END;
      
        if v_valid_input = 'Y' then
          v_output := 'Y';
        else
          v_output := 'INVALID_WAVE';
          return;
        end if;
      
      elsif (object_type = 'K' or object_type = 'k') then
      
        Begin
        
          select 'Y'
            into v_valid_input
          
            from pkt_hdr ph
           where ph.pkt_ctrl_nbr = print_object
             and (ph.cd_master_id = v_cd_master_id)
             and rownum < 2;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'INVALID PKT';
            RETURN;
        END;
      
        if v_valid_input = 'Y' then
          v_output := 'Y';
          return;
        else
          v_output := 'INVALID PKT';
          return;
        end if;
      
      elsif (object_type = 'T' or object_type = 't') then
      
        Begin
        
          select distinct 'Y'
            into v_valid_input
            from task_hdr th
            JOIN task_dtl td
              on th.task_id = td.task_id
           where th.doc_id = print_object
           group by td.cd_master_id;
        
        EXCEPTION
          WHEN No_Data_Found THEN
            v_output := 'INVALID Tote';
            RETURN;
        END;
      
        if v_valid_input = 'Y' then
          v_output := 'Y';
          return;
        else
          v_output := 'INVALID Tote';
          return;
        end if;
      
      end if;
    
    end if;
    --user wants to reprint tote
  elsif (p_prt_reqstr is not NULL and object_type is not NULL AND
        print_object is not NULL and
        (reprint_or_regenerate = 'R' or reprint_or_regenerate = 'r')) Then
  
    Begin
      SELECT prt_q_name
        INTO v_printq_name
        FROM prt_q_dest pqd, prt_q_master pqm, PRT_Q_SERV pqs
      -- pqd.whse = 'CV4'
       where PQD.PRT_REQSTR = p_prt_reqstr
         and PQD.PRT_Q_ID = pqm.prt_Q_ID
         AND PQD.PRT_SERV_TYPE = '03'
         and PQD.PRT_SERV_TYPE = PQS.PRT_SERV_TYPE
         and PQS.PRT_Q_ID = PQM.PRT_Q_ID
         AND ROWNUM < 2;
    EXCEPTION
      WHEN No_Data_Found then
        v_output := 'No Print Q Found';
        return;
      
    End;
  
    if (object_type = 'C' or object_type = 'c') then
    
      BEGIN
      
        For r_results IN (
                          
                          Select *
                            from ups_tcl_table tcl
                           where tcl.print_id in
                                 (select max(print_id)
                                    from ups_tcl_table
                                   where task_id = tcl.task_id
                                     and carton_nbr = print_object
                                   group by task_id)
                          
                          ) LOOP
        
          Begin
          
            select ups_tcl_table_seq.nextval into v_sequence from dual;
          
            insert into ups_tcl_table
              (print_id,
               wave_nbr,
               carton_nbr,
               task_id,
               prt_q_name,
               stat_code,
               label_seq,
               label_str,
               print_job_id,
               print_error_info,
               misc_field_1,
               misc_field_2,
               misc_field_3,
               misc_field_4,
               misc_field_5,
               create_date_time,
               mod_date_time,
               user_id)
            values
              (v_sequence,
               r_results.wave_nbr,
               r_results.carton_nbr,
               r_results.task_id,
               v_printq_name,
               12,
               r_results.label_seq,
               r_results.label_str,
               r_results.print_job_id,
               r_results.print_error_info,
               r_results.misc_field_1,
               r_results.misc_field_2,
               r_results.misc_field_3,
               r_results.misc_field_4,
               r_results.misc_field_5,
               r_results.create_date_time,
               sysdate,
               r_results.user_id);
          
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN NO_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
          v_output := 'Y';
          return;
        else
          v_output := 'No Record Found';
          return;
        
        end if;
      
      exception
        when no_data_found then
          v_output := 'No Task Found';
          return;
        
      END;
    
    elsif (object_type = 'W' or object_type = 'w') then
    
      Begin
      
        For r_results IN (
                          
                          Select *
                            from ups_tcl_table tcl
                           where tcl.print_id in
                                 (select max(print_id)
                                    from ups_tcl_table tcl
                                   where task_id = tcl.task_id
                                     and wave_nbr = print_object
                                   group by task_id)
                          
                          ) LOOP
        
          Begin
          
            select ups_tcl_table_seq.nextval into v_sequence from dual;
          
            insert into ups_tcl_table
              (print_id,
               wave_nbr,
               carton_nbr,
               task_id,
               prt_q_name,
               stat_code,
               label_seq,
               label_str,
               print_job_id,
               print_error_info,
               misc_field_1,
               misc_field_2,
               misc_field_3,
               misc_field_4,
               misc_field_5,
               create_date_time,
               mod_date_time,
               user_id)
            values
              (v_sequence,
               r_results.wave_nbr,
               r_results.carton_nbr,
               r_results.task_id,
               v_printq_name,
               12,
               r_results.label_seq,
               r_results.label_str,
               r_results.print_job_id,
               r_results.print_error_info,
               r_results.misc_field_1,
               r_results.misc_field_2,
               r_results.misc_field_3,
               r_results.misc_field_4,
               r_results.misc_field_5,
               r_results.create_date_time,
               sysdate,
               r_results.user_id);
          
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN NO_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
          v_output := 'Y';
          return;
        else
          v_output := 'No Record Found';
          return;
        
        end if;
      
      exception
        when no_data_found then
          v_output := 'No Task Found';
          return;
        
      END;
    
    elsif (object_type = 'K' or object_type = 'k') then
    
      Begin
      
        For r_results IN (
                          
                          Select *
                            from ups_tcl_table tcl
                           where tcl.print_id in
                                 (select max(print_id)
                                    from ups_tcl_table utt
                                    join carton_hdr ch
                                      on utt.carton_nbr = ch.carton_nbr
                                     and ch.pkt_ctrl_nbr = print_object
                                   where task_id = utt.task_id
                                   group by utt.task_id)
                          
                          ) LOOP
        
          Begin
            select ups_tcl_table_seq.nextval into v_sequence from dual;
          
            insert into ups_tcl_table
              (print_id,
               wave_nbr,
               carton_nbr,
               task_id,
               prt_q_name,
               stat_code,
               label_seq,
               label_str,
               print_job_id,
               print_error_info,
               misc_field_1,
               misc_field_2,
               misc_field_3,
               misc_field_4,
               misc_field_5,
               create_date_time,
               mod_date_time,
               user_id)
            values
              (v_sequence,
               r_results.wave_nbr,
               r_results.carton_nbr,
               r_results.task_id,
               v_printq_name,
               12,
               r_results.label_seq,
               r_results.label_str,
               r_results.print_job_id,
               r_results.print_error_info,
               r_results.misc_field_1,
               r_results.misc_field_2,
               r_results.misc_field_3,
               r_results.misc_field_4,
               r_results.misc_field_5,
               r_results.create_date_time,
               sysdate,
               r_results.user_id);
          
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN NO_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
          v_output := 'Y';
          return;
        else
          v_output := 'No Record Found';
          return;
        
        end if;
      
      exception
        when no_data_found then
          v_output := 'No Task Found';
          return;
        
      END;
    
    elsif (object_type = 'T' or object_type = 't') then
    
      Begin
      
        For r_results IN (
                          
                          Select *
                            from ups_tcl_table tcl
                           where tcl.print_id in
                                 (select max(print_id)
                                    from ups_tcl_table utt
                                    join task_hdr th
                                      on utt.task_id = th.task_id
                                   where th.doc_id = print_object
                                   group by utt.task_id)
                          
                          ) LOOP
        
          Begin
            select ups_tcl_table_seq.nextval into v_sequence from dual;
          
            insert into ups_tcl_table
              (print_id,
               wave_nbr,
               carton_nbr,
               task_id,
               prt_q_name,
               stat_code,
               label_seq,
               label_str,
               print_job_id,
               print_error_info,
               misc_field_1,
               misc_field_2,
               misc_field_3,
               misc_field_4,
               misc_field_5,
               create_date_time,
               mod_date_time,
               user_id)
            values
              (v_sequence,
               r_results.wave_nbr,
               r_results.carton_nbr,
               r_results.task_id,
               v_printq_name,
               12,
               r_results.label_seq,
               r_results.label_str,
               r_results.print_job_id,
               r_results.print_error_info,
               r_results.misc_field_1,
               r_results.misc_field_2,
               r_results.misc_field_3,
               r_results.misc_field_4,
               r_results.misc_field_5,
               r_results.create_date_time,
               sysdate,
               r_results.user_id);
          
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN NO_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
          v_output := 'Y';
          return;
        else
          v_output := 'No Record Found';
          return;
        
        end if;
      
      exception
        when no_data_found then
          v_output := 'No Task Found';
          return;
        
      END;
    
    end if;
  
    --user wants to generate new tote
  elsif (p_prt_reqstr is not NULL and object_type is not NULL AND
        print_object is not NULL and
        (reprint_or_regenerate = 'G' or reprint_or_regenerate = 'g')) Then
  
    Begin
    
      SELECT prt_q_name
        INTO v_printq_name
        FROM prt_q_dest pqd, prt_q_master pqm, PRT_Q_SERV pqs
      -- pqd.whse = 'CV4'
       where PQD.PRT_REQSTR = p_prt_reqstr
         and PQD.PRT_Q_ID = pqm.prt_Q_ID
         AND PQD.PRT_SERV_TYPE = '03'
         and PQD.PRT_SERV_TYPE = PQS.PRT_SERV_TYPE
         and PQS.PRT_Q_ID = PQM.PRT_Q_ID
         AND ROWNUM < 2;
    
    Exception
      when no_data_found then
        v_output := 'Printer Q Not Found';
        return;
      
    END;
  
    if (object_type = 'C' or object_type = 'c') then
    
      Begin
      
        For r_results IN (
                          
                          select distinct (td.task_id),
                                           td.task_genrtn_ref_nbr,
                                           td.sku_id
                          
                            from task_dtl td
                            join carton_hdr ch
                              on td.task_genrtn_ref_nbr = ch.wave_nbr
                             and td.task_cmpl_ref_nbr = ch.carton_nbr
                           where td.task_cmpl_ref_nbr = print_object
                          
                          ) LOOP
        
          begin
          
            select distinct (im.convey_flag)
              into v_convey_flag
              from item_master im
              join task_dtl td
                on td.sku_id = im.sku_id
             where td.task_id = r_results.task_id
               and td.invn_need_type = '50'
               and im.convey_flag = 'Y'
               and im.sku_id = r_results.sku_id;
          
            if (v_convey_flag = 'Y') then
            
              select ups_tcl_table_seq.nextval into v_sequence from dual;
            
              ups_stage_tcl_pkg.stage_tote_labels(r_results.task_id,
                                                  v_printq_name,
                                                  r_results.task_genrtn_ref_nbr,
                                                  v_sequence,
                                                  p_rc);
            end if;
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN No_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
        
          v_output := 'Y';
          return;
        else
          v_output := 'No Eligible TCL';
          return;
        end if;
      
      exception
      
        when no_data_found then
          v_output := 'No Eligible TCL';
          return;
        
      END;
    
    elsif (object_type = 'W' or object_type = 'w') then
    
      Begin
      
        For r_results IN (
                          
                          select distinct (td.task_id),
                                           ch.wave_nbr,
                                           td.sku_id
                          
                            from task_dtl td
                            join carton_hdr ch
                          
                              on td.carton_nbr = ch.carton_nbr
                           where ch.wave_nbr = print_object
                          
                          ) LOOP
        
          begin
          
            select distinct (im.convey_flag)
              into v_convey_flag
              from item_master im
              join task_dtl td
                on td.sku_id = im.sku_id
             where td.task_id = r_results.task_id
               and td.invn_need_type = '50'
               and im.convey_flag = 'Y'
               and im.sku_id = r_results.sku_id;
          
            if (v_convey_flag = 'Y') then
            
              select ups_tcl_table_seq.nextval into v_sequence from dual;
            
              ups_stage_tcl_pkg.stage_tote_labels(r_results.task_id,
                                                  v_printq_name,
                                                  print_object,
                                                  v_sequence,
                                                  p_rc);
            end if;
            number_of_rows_updated := sql%rowcount;
            lNumRecs               := lNumRecs + number_of_rows_updated;
            commit;
          
          EXCEPTION
            WHEN No_Data_Found THEN
              null;
          END;
        
        END LOOP;
      
        if (lNumRecs > 0) then
        
          v_output := 'Y';
          return;
        else
          v_output := 'No Eligible TCL';
          return;
        end if;
      
      exception
      
        when no_data_found then
          v_output := 'No Eligible TCL';
          return;
        
      END;
    
    elsif (object_type = 'K' or object_type = 'k') then
    
      Begin
      
        For r_results IN (
                          
                          select task_id, phi.pick_wave_nbr, sku_id
                            from task_dtl td
                            join pkt_hdr_intrnl phi
                              on td.task_genrtn_ref_nbr = phi.pick_wave_nbr
                           where phi.pkt_ctrl_nbr = print_object
                             and td.stat_code < 99
                          
                          ) LOOP
        
          select ups_tcl_table_seq.nextval into v_sequence from dual;
        
          Begin
            select distinct (im.convey_flag)
              into v_convey_flag
              from item_master im
              join task_dtl td
                on td.sku_id = im.sku_id
             where td.task_id = r_results.task_id
               and td.invn_need_type = '50'
               and im.convey_flag = 'Y'
               and im.sku_id = r_results.sku_id;
          Exception
            when no_data_found then
              v_convey_flag := 'N';
          End;
        
          if (v_convey_flag = 'Y') then
          
            ups_stage_tcl_pkg.stage_tote_labels(r_results.task_id,
                                                v_printq_name,
                                                r_results.pick_wave_nbr,
                                                v_sequence,
                                                p_rc);
          
            number_of_rows_updated := sql%rowcount;
          
            lNumRecs := lNumRecs + number_of_rows_updated;
            commit;
          end if;
        
        END LOOP;
      
        if (lNumRecs > 0) then
        
          v_output := 'Y';
          return;
        else
          v_output := 'No Eligible TCL';
          return;
        end if;
      
      exception
      
        when no_data_found then
          v_output := 'No ELigible TCL';
          return;
        
      END;
    
    elsif (object_type = 'T' or object_type = 't') then
    
      Begin
      
        select max(th.task_id)
          into v_task_id
          from task_hdr th
         where th.doc_id = print_object;
        
      
        select sku_id
          into v_sku_id
          from task_hdr th
         where th.task_id = v_task_id;
      
        select im.convey_flag, td.task_genrtn_ref_nbr
          into v_convey_flag, v_wave_nbr
          from item_master im
          join task_dtl td
            on td.sku_id = im.sku_id
         where td.task_id = v_task_id
           and td.invn_need_type = '50'
           and im.convey_flag = 'Y'
           and rownum = '1';
        --  and im.sku_id = v_sku_id
        --  group by td.task_genrtn_ref_nbr;
      
        if (v_convey_flag = 'Y') then
          select ups_tcl_table_seq.nextval into v_sequence from dual;
          ups_stage_tcl_pkg.stage_tote_labels(v_task_id,
                                              v_printq_name,
                                              v_wave_nbr,
                                              v_sequence,
                                              p_rc);
        end if;
      
        number_of_rows_updated := sql%rowcount;
      
        commit;
      
        if (number_of_rows_updated > 0) then
        
          v_output := 'Y';
          return;
        else
          v_output := 'No Eligible TCL';
          return;
        end if;
      
      Exception
        when no_data_found then
          v_output := 'No Eligible TCL';
          return;
        
      END;
    
    end if;
  
  else
    v_output := 'INVALID CHOICE';
    return;
  
  end if;

END;
