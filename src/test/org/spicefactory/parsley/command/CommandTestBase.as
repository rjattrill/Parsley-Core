package org.spicefactory.parsley.command {

import org.flexunit.assertThat;
import org.hamcrest.collection.array;
import org.hamcrest.collection.arrayWithSize;
import org.hamcrest.number.greaterThanOrEqualTo;
import org.hamcrest.object.equalTo;
import org.spicefactory.lib.command.data.CommandData;
import org.spicefactory.lib.command.events.CommandFailure;
import org.spicefactory.lib.errors.AbstractMethodError;
import org.spicefactory.lib.errors.IllegalStateError;
import org.spicefactory.parsley.command.observer.CommandObservers;
import org.spicefactory.parsley.command.observer.CommandStatusFlags;
import org.spicefactory.parsley.command.target.AsyncCommand;
import org.spicefactory.parsley.command.trigger.Trigger;
import org.spicefactory.parsley.command.trigger.TriggerA;
import org.spicefactory.parsley.command.trigger.TriggerB;
import org.spicefactory.parsley.core.command.CommandManager;
import org.spicefactory.parsley.core.command.ObservableCommand;
import org.spicefactory.parsley.core.context.Context;
import org.spicefactory.parsley.core.scope.ScopeName;

/**
 * @author Jens Halm
 */
public class CommandTestBase {
	
	
	private var context: Context;
	private var manager: CommandManager;
	
	private var status: CommandStatusFlags;
	private var observers: CommandObservers;
	
	private var lastCommand: AsyncCommand;
	
	
	protected function setContext (value: Context): void {
		context = value;
		manager = context.scopeManager.getScope(ScopeName.GLOBAL).commandManager;
		status = context.getObjectByType(CommandStatusFlags) as CommandStatusFlags;
		observers = context.getObjectByType(CommandObservers) as CommandObservers;
	}
	
	
	[Test]
	public function singleCommand () : void {
		
		configureSingleCommand();
		
		validateManager(0);
		
		execute();
		
		validateManager(1);
		validateStatus(true);
		validateResults();
		
		complete(0, true);
		
		validateManager(0);
		validateStatus(false);
		validateResults(true);
		validateLifecycle();
		
	}
	
	[Test]
	public function commandSequence () : void {
		
		configureCommandSequence();
		
		validateManager(0);
		
		execute();
		
		validateManager(1);
		validateStatus(true);
		validateResults();
		
		complete(0);
		
		validateManager(1);
		validateStatus(true);
		validateResults("1");
		validateLifecycle();

		complete(0);
		
		validateManager(0);
		validateStatus(false);
		validateResults("1", "2");
		validateLifecycle();
		
	}
	
	[Test]
	public function parallelCommands () : void {
		
		configureParallelCommands();
		
		validateManager(0);
		
		execute();
		
		validateManager(2);
		validateStatus(true);
		validateResults();
		
		complete(0);
		
		validateManager(1);
		validateStatus(true);
		validateResults("1");
		validateLifecycle();

		complete(0);
		
		validateManager(0);
		validateStatus(false);
		validateResults("1", "2");
		validateLifecycle();
		
	}
	
	[Test]
	public function commandFlow () : void {
		
		configureCommandFlow();
		
		validateManager(0);
		
		execute();
		
		validateManager(1);
		validateStatus(true);
		validateResults();
		
		complete(0);
		
		validateManager(1);
		validateStatus(true);
		validateResults("1");
		validateLifecycle();

		complete(0);
		
		validateManager(0);
		validateStatus(false);
		validateResults("1", "2");
		validateLifecycle();
		
	}
	
	[Test]
	public function cancelSequence () : void {
		
		configureCommandSequence();
		
		validateManager(0);
		
		execute();
		
		validateManager(1);
		validateStatus(true);
		validateResults();
		
		complete(0);
		
		validateManager(1);
		validateStatus(true);
		validateResults("1");
		validateLifecycle();

		cancel(0);
		
		validateManager(0);
		validateStatus(false);
		validateResults("1");
		validateLifecycle();
		
	}
	
	[Test]
	public function errorInSequence () : void {
		
		configureCommandSequence();
		
		validateManager(0);
		
		execute();
		
		validateManager(1);
		validateStatus(true);
		validateResults();
		
		complete(0);
		
		validateManager(1);
		validateStatus(true);
		validateResults("1");
		validateLifecycle();

		var e:Object = new IllegalStateError();
		complete(0, e);
		
		validateManager(0);
		validateStatus(false);
		validateResults("1");
		validateError(e);
		validateLifecycle();
		
	}
	
	
	protected function execute (): void {
		throw new AbstractMethodError();
	}
	
	protected function dispatchMessage (msg: Object): void {
		context.scopeManager.dispatchMessage(msg); 
	}
	
	protected function complete (index: uint, result: Object = null): void {
		setLastCommand(index);
		if (result) lastCommand.result = result;
		lastCommand.invokeCallback();
	}
	
	protected function cancel (index: uint, result: Object = null): void {
		setLastCommand(index);
		lastCommand.cancel();
	}
	
	private function setLastCommand (index: uint): void {
		var commands:Array = getActiveCommands(Trigger, AsyncCommand);
		assertThat(commands.length, greaterThanOrEqualTo(index + 1));
		lastCommand = commands[index].command as AsyncCommand;
	}
	
	protected function validateManager (cnt: uint): void {
		var commands:Array = getActiveCommands(Trigger, AsyncCommand);
		assertThat(commands, arrayWithSize(cnt));
		commands = getActiveCommands(TriggerA, AsyncCommand);
		assertThat(commands, arrayWithSize(cnt));
		commands = getActiveCommands(TriggerB, AsyncCommand);
		assertThat(commands, arrayWithSize(0));
	}
	
	private function getActiveCommands (trigger: Class, command: Class): Array {
		var commands:Array = manager.getActiveCommandsByTrigger(trigger);
		var result:Array = new Array();
		for each (var com:ObservableCommand in commands) {
			if (com.command is command) result.push(com);
		}
		return result;
	}
	
	protected function validateStatus (active: Boolean, result: Object = null, error: Object = null): void {
		assertThat(status.trigger, equalTo(active));
		assertThat(status.triggerA, equalTo(active));
		assertThat(status.triggerB, equalTo(false));
	}
	
	protected function validateResults (...results): void {
		assertThat(removeExecutorResults(observers.results), array(results));
		assertThat(removeExecutorResults(observers.resultsA), array(results));
		assertThat(removeExecutorResults(observers.resultsB), arrayWithSize(0));
	}
	
	private function removeExecutorResults (results: Array) : Array {
		var filtered:Array = [];
		for each (var result:Object in results) {
			if (result is CommandData) continue;
			filtered.push(result);
		}
		return filtered;
	}
	
	protected function validateError (error: Object): void {	
		if (error) {
			assertThat(observers.errors, arrayWithSize(1));
			assertThat(rootCause(observers.errors[0]), equalTo(error));
		}
		else {
			assertThat(observers.errors, arrayWithSize(0));
		}
	}
	
	private function rootCause (error: Object): Object {
		if (error is CommandFailure) {
			return rootCause(CommandFailure(error).cause);
		}
		else {
			return error;
		}
	}
	
	protected function validateLifecycle (destroyCount:uint = 1) : void {
		assertThat(lastCommand.destroyCount, equalTo(1));
	}

	protected function configureSingleCommand (): void {
		throw new AbstractMethodError();
	}
	
	protected function configureCommandSequence (): void {
		throw new AbstractMethodError();
	}
	
	protected function configureParallelCommands (): void {
		throw new AbstractMethodError();
	}
	
	protected function configureCommandFlow (): void {
		throw new AbstractMethodError();
	}
	
	
}
}
