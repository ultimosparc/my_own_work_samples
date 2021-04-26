CREATE TYPE UserTableType AS TABLE (id INT, instance_user VARCHAR(100))GO
CREATE TYPE InstanceTableType AS TABLE (id INT, instance VARCHAR(200))GO
CREATE PROCEDURE create_test_users (@users UserTableType READONLY, @instances InstanceTableType READONLY)
AS
BEGIN
	--Prüfen, ob alle Instanzen auch existieren, falls nicht, müssen erst die Parameter angepasst werden
	DECLARE @countedInstances INT, @loop_index INT, @validation_instances INT;
	DECLARE @current_instance VARCHAR(200);
	SET @validation_instances = 0 
	SET @countedInstances = (SELECT  COUNT(instance) FROM @instances);
	PRINT 'Anzahl der Instanzen:'
	PRINT @countedInstances
	SET @loop_index = 1; 
	PRINT 'Prüfung der Instanzen gestartet ...'
	WHILE (@loop_index <= @countedInstances)
	BEGIN
		SET @current_instance = (SELECT instance FROM @instances WHERE id = @loop_index)
		PRINT 'Prüfe folgende Instanz:'
		PRINT @current_instance
		IF NOT EXISTS (select * from [CISDARWIN].[dbo].[Instanz] where aliasinstanz like @current_instance) 
		BEGIN
			PRINT 'ERROR: Instanz ' + @current_instance + ' wurde nicht gefunden'
			PRINT 'Es gab keine Änderungen an den Datenbanken und Programm wurde abgebrochen'
			PRINT 'Instanzbezeichnung korrigieren und Programm erneut starten'
			SET @validation_instances = 1
			BREAK	
		END
		SET @loop_index = @loop_index + 1
	END
	IF @validation_instances = 0
	BEGIN
		PRINT 'Alle Instanzen wurden gefunden'
		DECLARE @countedUsers INT, @instance_id INT, @user_accounts_limit INT;
		SET @loop_index = 1;
		SET @user_accounts_limit = 7200000;
		SET @countedUsers = (SELECT  COUNT(instance_user) FROM @users);
		SET @countedInstances = (SELECT  COUNT(instance) FROM @instances);
	   --erste Schleife über die Users
		WHILE ( @loop_index <= @countedUsers)
		BEGIN
			--nehme den ersten User aus der Userliste
			PRINT 'Bestimme User Name ... '
			DECLARE @user_name VARCHAR(100)
			SET @user_name = (SELECT  instance_user FROM @users WHERE id = @loop_index)
			PRINT 'User Name: ' + @user_name;
			--1. Prüfe ob der User bereits existiert
			IF NOT EXISTS (SELECT comsi FROM [CISDARWIN].[dbo].[COMSI] WHERE comsi = @user_name)
			BEGIN--Falls es noch keinen User mit dem user name @user_name existiert
				--2.Bestimme ID
				PRINT 'Bestimme neue Benutzer ID ... '
				DECLARE @new_user_id INT
				SET @new_user_id = (SELECT MAX([ID])+1 FROM [CISDARWIN].[dbo].[COMSI])
				PRINT 'Neue Benutzer ID: ';
				PRINT @new_user_id;
				--3.Bestimme Personal Nummer
				DECLARE @new_personal_identification_number INT
				PRINT 'Bestimme neue Personalnummer ... '
				DECLARE @local_variable INT
				SET @local_variable = (SELECT MAX([PERSNR])+1 FROM [CISDARWIN].[dbo].[COMSI] WHERE [PERSNR] < @user_accounts_limit)
				IF @local_variable >= @user_accounts_limit
				BEGIN
					PRINT 'ERROR: Anzahl der möglichen Test User Konten wurde erreicht'
					PRINT 'Es gab keine Änderungen an den Datenbanken'
					PRINT 'Programm wurde beendet'
					BREAK
				END
				ELSE 
				BEGIN
					SET @new_personal_identification_number = @local_variable
					PRINT 'Neue Personalnummer: '
					PRINT  @new_personal_identification_number
				END
				--4. Füge den neuen Nutzer hinzu
				INSERT INTO [CISDARWIN].[dbo].[COMSI] 
					SELECT @new_user_id,@user_name,@new_personal_identification_number,@user_name,[VNAME],'Herr',[EINSWK],[KSTBEZ],[STELLE],[KST],[KST10],[KOEPFE],[KSTBEZ1],[EMAIL],[PHONE],[FAX]
					FROM [CISDARWIN].[dbo].[COMSI] WHERE [COMSI]='UC2TKFV' --prototyp test user/default test user --> don't change it 
				PRINT 'Ein neuer User mit dem Namen ' + @user_name + ' wurde angelegt' 
			
			END--Prüfung beendet, ob der User schon existiert
			--5. Prüfen ob es einen Mitarbeiter mit dem @user_name gibt
			PRINT 'Prüfe, ob der User als Mitarbeiter bereits existiert'
			IF NOT EXISTS (SELECT comsiid FROM [CISDARWIN].[dbo].[Mitarbeiter] WHERE comsiid in (@user_name))
			BEGIN
				--Falls nicht, dann füge einen neuen Test Mitarbeiter hinzu
				PRINT 'User wird als neuer Mitarbeiter angelegt'
				INSERT INTO [CISDARWIN].[dbo].[Mitarbeiter] VALUES(@user_name,'Testuserceres',NULL,@user_name,1,'de')
			END
			PRINT 'Update der Mitarbeiterinformationen bei den Instanzen ...'
			PRINT 'Anzahl der Instanzen:'
			PRINT @countedInstances
			DECLARE @instance_loop_index INT
			SET @instance_loop_index = 1

			--Der User hat noch keinen Eintrag
			WHILE ( @instance_loop_index <= @countedInstances)
			BEGIN
				PRINT 'Prüfe folgende Instanz:'
				SET @current_instance = (SELECT instance FROM @instances WHERE id = @instance_loop_index)
				PRINT @current_instance
				--7. Instanz ID bestimmen
				SET @instance_id = (SELECT id_instanz FROM [CISDARWIN].[dbo].[Instanz] WHERE aliasinstanz like @current_instance);
				PRINT 'Bestimme Instanz ID:'
				PRINT @instance_id;
				--8. Prüfen, ob der Mitarbeiter der Instanz schon hinzugefügt ist
				PRINT 'Prüfe, ob der Mitarbeiter der Instanz bereits zugeordnet ist ...'
				IF NOT EXISTS (SELECT fk_instanz,fk_mitarbeiter FROM [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter in (@user_name) AND fk_instanz IN (@instance_id))
				BEGIN --Falls, nicht
					--9. Ordne den Mitarbeiter der Instanz hinzu
					PRINT 'Neuer Mitarbeiter wird der Instanz zugeordnert'
					INSERT INTO [CISDARWIN].[dbo].[Mitarbeiter2Instanz] VALUES(@user_name,@instance_id,' ')		
				END
				ELSE
				BEGIN
					PRINT 'Mitarbeiter ' + @user_name + ' ist bereits der Instanz ' + @current_instance + ' zugeordnet'
				END 
				SET @instance_loop_index = @instance_loop_index + 1
			END
			PRINT 'Prüfe, ob dem Mitarbeiter eine Standardinstanz zugeordnet ist'
			--10. Prüfe, ob der Mitarbeiter eine Standardinstanz besitzt
			IF NOT EXISTS (SELECT fk_instanz,fk_mitarbeiter FROM [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter in (@user_name) AND instanzdefault='d')
			BEGIN
				PRINT 'Mitarbeiter besitzt keine Standardinstanz'
				--Falls nicht, dann setze die erste Instanz aus den Parametern als Standardinstanz
				SET @current_instance = (SELECT instance FROM @instances WHERE id=1)
				UPDATE [CISDARWIN].[dbo].[Mitarbeiter2Instanz] SET instanzdefault ='d' WHERE fk_instanz=(SELECT id_instanz FROM [CISDARWIN].[dbo].[Instanz] WHERE aliasinstanz like @current_instance) AND fk_mitarbeiter = @user_name
				PRINT 'Standardinstanz für Mitarbeiter wurde gesetzt'
			END
			ELSE
			BEGIN
				PRINT 'Standardinstanz ist bereits gesetzt'
				--Prüfe, ob genau eine Standinstanz für den User @user_name existiert, falls nicht, lösche die anderen Standardinstanzen
				--zähle die Instanzen die als Standardinstanz definiert werden
				DECLARE @countedDefaultInstances INT
				--Erstelle die Tabelle von Default Instanzen
				PRINT 'Prüfe, ob die Einstellung der Standardinstanz eindeutig ist'
				SELECT ROW_NUMBER() OVER(ORDER BY fk_instanz DESC) AS id,  fk_instanz INTO table_default_instances FROM [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter = @user_name AND instanzdefault='d'
				SET @countedDefaultInstances = (SELECT COUNT(*) FROM table_default_instances )
				PRINT 'Anzahl der Standardinstanzen für den Mitarbeiter >> ' + @user_name + ' <<'
				PRINT @countedDefaultInstances
				SET @countedDefaultInstances = (SELECT COUNT(*) FROM table_default_instances )
				IF (@countedDefaultInstances >= 2)
				BEGIN
					PRINT 'Mitarbeiter hat mehrere Standardinstanzen'
					PRINT 'Korrigiere die Einstellungen'
					
					SET @instance_loop_index = 2; 
					WHILE @instance_loop_index <= @countedDefaultInstances
					BEGIN
						UPDATE [CISDARWIN].[dbo].[Mitarbeiter2Instanz] SET instanzdefault='' WHERE fk_instanz=(SELECT fk_instanz FROM table_default_instances WHERE id=@instance_loop_index) AND fk_mitarbeiter=@user_name
						
						SET @instance_loop_index = @instance_loop_index + 1;
					END
					
					--Prüfen, ob der User @user_name genau eine Standardinstanz hat
					IF (SELECT COUNT(*) FROM [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter='AP2ACHT' AND instanzdefault='d') = 1
					BEGIN
						PRINT 'Mitarbeiter hat nur noch eine Standardinstanz'
					END
					ELSE
					BEGIN
						PRINT 'ERROR: Update der Instanzen ist nicht korrekt ausgeführt worden'
						PRINT 'Bitte [CISDARWIN].[dbo].[Mitarbeiter2Instanz] prüfen'
					END
				END
				ELSE
				BEGIN
					PRINT 'Der Mitarbeiter hat genau eine Standardinstanz gesetzt'
				END
				DROP TABLE table_default_instances
			END
			PRINT 'Bearbeitung des Mitarbeiter beendet'	
			SET @loop_index =  @loop_index + 1		
		END
	END 
END
GO
CREATE PROCEDURE execute_sript_adding_test_users 
AS
BEGIN
--Deklaration der Tabellen für die Erstellung der Testusers
--DECLARE @users UserTableType
--DECLARE @instances InstanceTableType

--Testfall 1 
--INSERT INTO @users VALUES(1,'test user');
--INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');


--Testfall 2 
--INSERT INTO @users VALUES(1,'test user');
--INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');
--INSERT INTO @instances VALUES(2,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF_test');

--Testfall 3 
--INSERT INTO @users VALUES(1,'test user');
--INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');
--INSERT INTO @instances VALUES(2,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');

--Testfall 3 
--INSERT INTO @users VALUES(1,'test user');
--INSERT INTO @users VALUES(2,'test user');
--INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');
--INSERT INTO @instances VALUES(2,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');

--Testfall 4 
--INSERT INTO @users VALUES(1,'test user');
--INSERT INTO @users VALUES(2,'test user 1');
--INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');
--INSERT INTO @instances VALUES(2,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');

--Für das Testen des Skripts
--BEGIN TRAN
--BEGIN TRY
--	EXECUTE create_test_users @users, @instances
--	ROLLBACK TRAN
--END TRY
--BEGIN CATCH
--  ROLLBACK TRAN
--END CATCH

--Für das Ausführen des Skripts selbst
DECLARE @users UserTableType
DECLARE @instances InstanceTableType

INSERT INTO @users VALUES(1,'test user');
INSERT INTO @instances VALUES(1,'GS-BO:MS:3:MU:FKS-4.0:2.2.3:OD:RuF');


BEGIN TRAN
BEGIN TRY
	EXECUTE create_test_users @users, @instances
	COMMIT TRAN
END TRY
BEGIN CATCH
  ROLLBACK TRAN
END CATCH

--SELECT * FROM [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter in ('test user') 
--SELECT * FROM [CISDARWIN].[dbo].[Mitarbeiter] WHERE comsiid='test user'
--SELECT * FROM [CISDARWIN].[dbo].[COMSI] WHERE NAME='test user'
--DELETE FROM  [CISDARWIN].[dbo].[Mitarbeiter2Instanz] WHERE fk_mitarbeiter in ('test user') 
--DELETE FROM [CISDARWIN].[dbo].[COMSI] WHERE NAME='test user'
--DELETE FROM [CISDARWIN].[dbo].[Mitarbeiter] WHERE comsiid='test user'
END	
GO